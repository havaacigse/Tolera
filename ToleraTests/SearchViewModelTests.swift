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
        func deleteAll() { storage.removeAll() }
        func all() -> [SavedIngredientsText] { Array(storage.values) }
    }

    private final class MockScanHistoryRepository: ScanHistoryRepository, @unchecked Sendable {
        private(set) var savedEntries: [ScanHistoryEntry] = []

        func save(_ entry: ScanHistoryEntry) { savedEntries.append(entry) }
        func all() -> [ScanHistoryEntry] { savedEntries }
        func delete(id: UUID) {}
        func deleteAll() { savedEntries.removeAll() }
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
        func resetAll() { allergens = []; customTerms = [] }
    }

    private func makeSavedRecord(
        barcode: String = "123",
        ingredientsText: String = "su, şeker",
        rawText: String? = nil,
        headingFound: Bool = true
    ) -> SavedIngredientsText {
        SavedIngredientsText(
            barcode: barcode,
            productName: "Hafızadaki Ürün",
            brand: "Marka",
            imageURL: URL(string: "https://example.com/image.jpg"),
            categories: ["yogurts"],
            ingredientsText: ingredientsText,
            rawText: rawText,
            headingFound: headingFound,
            savedAt: Date()
        )
    }

    private func makeViewModel(
        productRepository: MockProductRepository,
        savedIngredientsTextRepository: MockSavedIngredientsTextRepository,
        scanHistoryRepository: MockScanHistoryRepository = MockScanHistoryRepository(),
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
            savedIngredientsTextRepository: savedIngredientsTextRepository,
            scanHistoryRepository: scanHistoryRepository
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

    /// Güvenlik gerilemesi testi: ilk taramada (OCR) yakalanan bir uyarı, aynı ürün hafızadan
    /// (ikinci kez) kontrol edilince KAÇIRILMAMALI — "ilk okutmada dikkat, ikincisinde uygun"
    /// olamaz. `saved.rawText` doluysa `detectWarningSentences` hafıza yolunda da çalışmalı.
    @Test("Kaydın rawText'inde 'Fındık içerebilir' varsa, hafızadan tekrar kontrolde fındık mayContain olur")
    func savedRecordRawTextTriggersWarningSentenceRescan() async throws {
        let saved = makeSavedRecord(
            ingredientsText: "şeker, kakao",
            rawText: "İçindekiler: şeker, kakao. Besin değerleri: Enerji 500 kcal. Alerjen uyarısı: Fındık içerebilir."
        )
        let profileRepository = MockUserProfileRepository()
        profileRepository.allergens = [.nuts]
        let viewModel = makeViewModel(
            productRepository: MockProductRepository(),
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(preloaded: [saved]),
            profileRepository: profileRepository
        )
        viewModel.barcode = "123"

        viewModel.search()

        #expect(viewModel.result?.status == .caution)
        #expect(viewModel.result?.matchedTraces.contains(.nuts) == true)
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

    /// Güvenlik gerilemesi testi: hafızadan bir kayıt silindikten (ör. Profil ekranından
    /// "Kaydedilen ürünler" listesinden) sonra aynı barkod tekrar arandığında, artık var
    /// olmayan eski metin KULLANILMAMALI — arama normal OFF (ağ) akışına düşmeli.
    @Test("Hafızadaki kayıt silindikten sonra aynı barkod tekrar arandığında eski metin kullanılmaz, OFF'a (ağa) gidilir")
    func searchAfterDeletingSavedProductGoesToNetwork() async throws {
        let saved = makeSavedRecord(barcode: "123", ingredientsText: "süt tozu, şeker")
        let savedRepository = MockSavedIngredientsTextRepository(preloaded: [saved])
        let productRepository = MockProductRepository()
        productRepository.productToReturn = Product(
            barcode: "123",
            name: "Ağdan Gelen Ürün",
            brand: "OFF Marka",
            imageURL: nil,
            ingredientsText: "su, şeker",
            allergens: [],
            traces: [],
            categories: [],
            type: .food
        )
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: savedRepository
        )
        viewModel.barcode = "123"

        savedRepository.delete(barcode: "123")
        viewModel.search()

        try await waitUntil { viewModel.result != nil }

        #expect(productRepository.productCallCount == 1)
        #expect(viewModel.savedIngredientsTextSource == nil)
        #expect(viewModel.result?.product.name == "Ağdan Gelen Ürün")
    }

    // MARK: - Adım B: otomatik OCR yönlendirmesi

    @Test("Ürün bulunamadığında (profil boş değilken) OCR ekranına otomatik yönlendirme tetiklenir")
    func productNotFoundTriggersAutoRedirect() async throws {
        let productRepository = MockProductRepository()
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository()
        )
        viewModel.barcode = "555"

        viewModel.search()
        try await waitUntil { viewModel.isProductNotFound }

        #expect(viewModel.pendingIngredientsScanContext?.barcode == "555")
        #expect(viewModel.pendingIngredientsScanContext?.productName == nil)
    }

    @Test("Ürün bulundu ama içindekiler metni yoksa, ürün bilgisiyle birlikte OCR'a yönlendirilir")
    func missingIngredientsTextTriggersAutoRedirectWithProductInfo() async throws {
        let productRepository = MockProductRepository()
        productRepository.productToReturn = Product(
            barcode: "777", name: "Boş Ürün", brand: "Marka X",
            imageURL: URL(string: "https://example.com/x.jpg"),
            ingredientsText: nil, allergens: [], traces: [], categories: ["snacks"], type: .food
        )
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository()
        )
        viewModel.barcode = "777"

        viewModel.search()
        try await waitUntil { viewModel.pendingIngredientsScanContext != nil }

        #expect(viewModel.pendingIngredientsScanContext?.barcode == "777")
        #expect(viewModel.pendingIngredientsScanContext?.productName == "Boş Ürün")
        #expect(viewModel.pendingIngredientsScanContext?.brand == "Marka X")
        #expect(viewModel.pendingIngredientsScanContext?.categories == ["snacks"])
    }

    @Test("Dil anlaşılamadığı için sonuç unknown dönerse de OCR'a yönlendirilir")
    func unrecognizedLanguageTriggersAutoRedirect() async throws {
        let productRepository = MockProductRepository()
        productRepository.productToReturn = Product(
            barcode: "666", name: "Yabancı Etiket", brand: nil, imageURL: nil,
            ingredientsText: "Этот продукт содержит пшеницу", allergens: [], traces: [], categories: [], type: .food
        )
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository()
        )
        viewModel.barcode = "666"

        viewModel.search()
        try await waitUntil { viewModel.pendingIngredientsScanContext != nil }

        #expect(viewModel.pendingIngredientsScanContext?.barcode == "666")
    }

    @Test("Kozmetik üründe (unknown olsa da) OCR'a otomatik yönlendirme yapılmaz")
    func cosmeticProductDoesNotTriggerAutoRedirect() async throws {
        let productRepository = MockProductRepository()
        productRepository.productToReturn = Product(
            barcode: "888", name: "Kozmetik", brand: nil, imageURL: nil,
            ingredientsText: nil, allergens: [], traces: [], categories: [], type: .cosmetic
        )
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository()
        )
        viewModel.barcode = "888"

        viewModel.search()
        try await waitUntil { viewModel.result != nil }

        #expect(viewModel.pendingIngredientsScanContext == nil)
    }

    @Test("Profil boşsa ürün bulunamasa da OCR'a otomatik yönlendirme yapılmaz")
    func emptyProfileDoesNotTriggerAutoRedirectEvenWhenNotFound() async throws {
        let productRepository = MockProductRepository()
        let profileRepository = MockUserProfileRepository()
        profileRepository.allergens = []
        profileRepository.customTerms = []
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(),
            profileRepository: profileRepository
        )
        viewModel.barcode = "999"

        viewModel.search()
        try await waitUntil { viewModel.isProductNotFound }

        #expect(viewModel.pendingIngredientsScanContext == nil)
    }

    @Test("Normal (metin var, dil anlaşılan) sonuçta OCR'a otomatik yönlendirme yapılmaz")
    func normalResultDoesNotTriggerAutoRedirect() async throws {
        let productRepository = MockProductRepository()
        productRepository.productToReturn = Product(
            barcode: "111", name: "Normal Ürün", brand: nil, imageURL: nil,
            ingredientsText: "su, şeker", allergens: [], traces: [], categories: [], type: .food
        )
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository()
        )
        viewModel.barcode = "111"

        viewModel.search()
        try await waitUntil { viewModel.result != nil }

        #expect(viewModel.pendingIngredientsScanContext == nil)
        #expect(viewModel.result?.status == .safe)
    }

    @Test("Her search() çağrısı yönlendirme bağlamını önce sıfırlar: bir önceki aramadan kalan yönlendirme yeni aramaya taşınmaz")
    func newSearchClearsPreviousRedirectContext() async throws {
        let productRepository = MockProductRepository()
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository()
        )
        viewModel.barcode = "555"
        viewModel.search()
        try await waitUntil { viewModel.pendingIngredientsScanContext != nil }

        // Kullanıcı OCR ekranından fotoğraf çekmeden geri döndü (SwiftUI binding'i nil'e çevirir).
        viewModel.pendingIngredientsScanContext = nil

        // Normal sonuç veren FARKLI bir arama: bu da kendi kararını baştan verir.
        productRepository.productToReturn = Product(
            barcode: "222", name: "Başka Ürün", brand: nil, imageURL: nil,
            ingredientsText: "su, şeker", allergens: [], traces: [], categories: [], type: .food
        )
        viewModel.barcode = "222"
        viewModel.search()
        try await waitUntil { viewModel.result != nil }

        #expect(viewModel.pendingIngredientsScanContext == nil)
    }

    // MARK: - Adım D: tarama geçmişi kaydı

    @Test("Barkod hafızasından üretilen sonuç hemen geçmişe kaydedilir (kaynak: ocrPhoto)")
    func savedRecordResultIsLoggedToHistoryImmediately() async throws {
        let saved = makeSavedRecord()
        let scanHistoryRepository = MockScanHistoryRepository()
        let viewModel = makeViewModel(
            productRepository: MockProductRepository(),
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(preloaded: [saved]),
            scanHistoryRepository: scanHistoryRepository
        )
        viewModel.barcode = "123"

        viewModel.search()

        #expect(scanHistoryRepository.savedEntries.count == 1)
        #expect(scanHistoryRepository.savedEntries.first?.source == .ocrPhoto)
        #expect(scanHistoryRepository.savedEntries.first?.barcode == "123")
    }

    @Test("Yönlendirme tetiklenmeyen normal OFF sonucu hemen geçmişe kaydedilir (kaynak: off)")
    func normalOffResultIsLoggedToHistoryImmediately() async throws {
        let productRepository = MockProductRepository()
        productRepository.productToReturn = Product(
            barcode: "111", name: "Normal Ürün", brand: nil, imageURL: nil,
            ingredientsText: "su, şeker", allergens: [], traces: [], categories: [], type: .food
        )
        let scanHistoryRepository = MockScanHistoryRepository()
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(),
            scanHistoryRepository: scanHistoryRepository
        )
        viewModel.barcode = "111"

        viewModel.search()
        try await waitUntil { viewModel.result != nil }

        #expect(scanHistoryRepository.savedEntries.count == 1)
        #expect(scanHistoryRepository.savedEntries.first?.source == .off)
        #expect(scanHistoryRepository.savedEntries.first?.snapshotStatus == .safe)
    }

    @Test("OCR'a yönlendirilen 'ara' unknown sonucu, kullanıcı henüz vazgeçmediyse geçmişe HENÜZ kaydedilmez")
    func redirectedResultIsNotLoggedWhilePending() async throws {
        let productRepository = MockProductRepository()
        productRepository.productToReturn = Product(
            barcode: "777", name: "Boş Ürün", brand: nil, imageURL: nil,
            ingredientsText: nil, allergens: [], traces: [], categories: [], type: .food
        )
        let scanHistoryRepository = MockScanHistoryRepository()
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(),
            scanHistoryRepository: scanHistoryRepository
        )
        viewModel.barcode = "777"

        viewModel.search()
        try await waitUntil { viewModel.pendingIngredientsScanContext != nil }

        #expect(scanHistoryRepository.savedEntries.isEmpty)
    }

    @Test("Kullanıcı OCR'dan fotoğraf çekmeden vazgeçerse, bekleyen 'ara' unknown sonucu O ZAMAN geçmişe kaydedilir")
    func dismissingIngredientsScanLogsThePendingResult() async throws {
        let productRepository = MockProductRepository()
        let scanHistoryRepository = MockScanHistoryRepository()
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(),
            scanHistoryRepository: scanHistoryRepository
        )
        viewModel.barcode = "555"

        viewModel.search()
        try await waitUntil { viewModel.isProductNotFound }
        #expect(scanHistoryRepository.savedEntries.isEmpty)

        viewModel.ingredientsScanDismissedWithoutCompleting()

        #expect(viewModel.pendingIngredientsScanContext == nil)
        #expect(scanHistoryRepository.savedEntries.count == 1)
        #expect(scanHistoryRepository.savedEntries.first?.barcode == "555")
        #expect(scanHistoryRepository.savedEntries.first?.snapshotStatus == .unknown)
        #expect(scanHistoryRepository.savedEntries.first?.source == .off)
    }

    @Test("Profil boşken bulunan bir üründe (yönlendirme de yok) hiçbir şey geçmişe kaydedilmez")
    func emptyProfileResultIsNotLoggedToHistory() async throws {
        let productRepository = MockProductRepository()
        productRepository.productToReturn = Product(
            barcode: "222", name: "Ürün", brand: nil, imageURL: nil,
            ingredientsText: "su, şeker", allergens: [], traces: [], categories: [], type: .food
        )
        let profileRepository = MockUserProfileRepository()
        profileRepository.allergens = []
        profileRepository.customTerms = []
        let scanHistoryRepository = MockScanHistoryRepository()
        let viewModel = makeViewModel(
            productRepository: productRepository,
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(),
            scanHistoryRepository: scanHistoryRepository,
            profileRepository: profileRepository
        )
        viewModel.barcode = "222"

        viewModel.search()
        try await waitUntil { viewModel.result != nil }

        #expect(scanHistoryRepository.savedEntries.isEmpty)
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
