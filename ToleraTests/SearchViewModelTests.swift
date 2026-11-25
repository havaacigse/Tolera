import Foundation
import Testing
@testable import Tolera

/// `SearchViewModel`'in barkod hafızası önceliği (Aşama 3, Adım A) davranışını test eder.
/// Ağ (ProductRepository) ve yerel depo (SavedIngredientsTextRepository) sahte (mock)
/// implementasyonlarla izole edilir.
struct SearchViewModelTests {
    private final class MockProductRepository: ProductRepository, @unchecked Sendable {
        var productToReturn: Product?
        private(set) var productCallCount = 0

        func product(barcode: String) async throws -> Product {
            productCallCount += 1
            guard let productToReturn else { throw ProductError.notFound }
            return productToReturn
        }

        func products(inCategory category: String, excludingBarcode barcode: String) async throws -> [Product] {
            []
        }
    }

    private final class MockSavedIngredientsTextRepository: SavedIngredientsTextRepository, @unchecked Sendable {
        private var storage: [String: SavedIngredientsText]

        init(preloaded: [SavedIngredientsText] = []) {
            storage = Dictionary(uniqueKeysWithValues: preloaded.map { ($0.barcode, $0) })
        }

        func find(barcode: String) -> SavedIngredientsText? { storage[barcode] }
        func save(_ record: SavedIngredientsText) { storage[record.barcode] = record }
        func delete(barcode: String) { storage.removeValue(forKey: barcode) }
        func all() -> [SavedIngredientsText] { Array(storage.values) }
    }

    private final class MockUserProfileRepository: UserProfileRepository, @unchecked Sendable {
        var allergens: Set<Allergen> = [.milk]
        var customTerms: [String] = []

        func loadAllergens() -> Set<Allergen> { allergens }
        func save(allergens: Set<Allergen>) { self.allergens = allergens }
        func loadName() -> String? { nil }
        func save(name: String) {}
        func hasCompletedOnboarding() -> Bool { true }
        func setOnboardingCompleted() {}
        func loadCustomTerms() -> [String] { customTerms }
        func save(customTerms: [String]) { self.customTerms = customTerms }
    }

    private func makeSavedRecord(
        barcode: String = "123",
        ingredientsText: String = "su, şeker",
        headingFound: Bool = true
    ) -> SavedIngredientsText {
        SavedIngredientsText(
            barcode: barcode,
            productName: "Hafızadaki Ürün",
            brand: "Marka",
            imageURL: URL(string: "https://example.com/image.jpg"),
            categories: ["yogurts"],
            ingredientsText: ingredientsText,
            headingFound: headingFound,
            savedAt: Date()
        )
    }

    private func makeViewModel(
        productRepository: MockProductRepository,
        savedIngredientsTextRepository: MockSavedIngredientsTextRepository,
        profileRepository: MockUserProfileRepository = MockUserProfileRepository()
    ) -> SearchViewModel {
        let checkProductUseCase = CheckProductUseCase()
        return SearchViewModel(
            productRepository: productRepository,
            profileRepository: profileRepository,
            checkProductUseCase: checkProductUseCase,
            findAlternativesUseCase: FindAlternativesUseCase(
                productRepository: productRepository,
                checkProductUseCase: checkProductUseCase
            ),
            textRecognitionService: StubTextRecognitionService(),
            savedIngredientsTextRepository: savedIngredientsTextRepository
        )
    }

    @Test("Barkod hafızasında kayıt varsa OFF'a hiç gidilmez, sonuç hafızadan üretilir")
    func savedRecordTakesPriorityOverNetwork() async throws {
        let saved = makeSavedRecord(ingredientsText: "süt tozu, şeker")
        let productRepository = MockProductRepository()
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(preloaded: [saved])
        )
        viewModel.barcode = "123"

        viewModel.search()

        #expect(productRepository.productCallCount == 0)
        #expect(viewModel.result?.status == .unsafe)
        #expect(viewModel.result?.matchedAllergens.contains(.milk) == true)
        #expect(viewModel.savedIngredientsTextSource?.barcode == "123")
        #expect(viewModel.result?.product.brand == "Marka")
        #expect(viewModel.result?.product.categories == ["yogurts"])
    }

    @Test("Hafızadaki kaydın headingFound=false değeri aynen geçirilir: alerjen yoksa sonuç asla safe olmaz")
    func savedRecordHeadingFoundIsPassedThrough() async throws {
        let saved = makeSavedRecord(ingredientsText: "su, şeker", headingFound: false)
        let productRepository = MockProductRepository()
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(preloaded: [saved])
        )
        viewModel.barcode = "123"

        viewModel.search()

        #expect(viewModel.result?.status == .unknown)
        #expect(viewModel.result?.isMissingIngredientsHeading == true)
    }

    @Test("Barkod hafızasında kayıt yoksa normal OFF akışı çalışmayı sürdürür")
    func fallsBackToNetworkWhenNoSavedRecord() async throws {
        let productRepository = MockProductRepository()
        productRepository.productToReturn = Product(
            barcode: "999",
            name: "OFF Ürünü",
            brand: "OFF Marka",
            imageURL: nil,
            ingredientsText: "su, şeker",
            allergens: [],
            traces: [],
            categories: ["drinks"],
            type: .food
        )
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository()
        )
        viewModel.barcode = "999"

        viewModel.search()

        try await waitUntil { viewModel.result != nil }

        #expect(productRepository.productCallCount == 1)
        #expect(viewModel.savedIngredientsTextSource == nil)
        #expect(viewModel.result?.product.name == "OFF Ürünü")
    }

    /// `search()` fire-and-forget bir `Task` başlattığından, OFF yolunu test ederken
    /// sonucun gelmesini kısa bir polling ile bekler (production kodu değiştirmeden).
    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                Issue.record("Zaman aşımı: koşul \(timeout) saniyede sağlanmadı.")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

/// `TextRecognitionService`'in bu testlerde kullanılmayan sahte implementasyonu.
private struct StubTextRecognitionService: TextRecognitionService {
    func recognizeText(in imageData: Data, usesLanguageCorrection: Bool) async throws -> String { "" }
    func currentRecognitionLanguage() -> String { "tr-TR" }
}
