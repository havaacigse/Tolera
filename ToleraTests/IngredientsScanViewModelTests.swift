import Foundation
import Testing
@testable import Tolera

/// `IngredientsScanViewModel`'in, "Kontrol et" başarılı olduğunda barkod biliniyorsa
/// metni `SavedIngredientsTextRepository`'ye kaydetmesini test eder (Aşama 3, Adım C).
struct IngredientsScanViewModelTests {
    private final class MockSavedIngredientsTextRepository: SavedIngredientsTextRepository, @unchecked Sendable {
        private(set) var savedRecords: [SavedIngredientsText] = []

        func find(barcode: String) -> SavedIngredientsText? { nil }
        func save(_ record: SavedIngredientsText) { savedRecords.append(record) }
        func delete(barcode: String) {}
        func all() -> [SavedIngredientsText] { savedRecords }
    }

    private final class MockScanHistoryRepository: ScanHistoryRepository, @unchecked Sendable {
        private(set) var savedEntries: [ScanHistoryEntry] = []

        func save(_ entry: ScanHistoryEntry) { savedEntries.append(entry) }
        func all() -> [ScanHistoryEntry] { savedEntries }
        func delete(id: UUID) {}
        func deleteAll() { savedEntries.removeAll() }
    }

    private final class MockUserProfileRepository: UserProfileRepository, @unchecked Sendable {
        func loadAllergens() -> Set<Allergen> { [.milk] }
        func save(allergens: Set<Allergen>) {}
        func loadName() -> String? { nil }
        func save(name: String) {}
        func hasCompletedOnboarding() -> Bool { true }
        func setOnboardingCompleted() {}
        func loadCustomTerms() -> [String] { [] }
        func save(customTerms: [String]) {}
    }

    private struct StubTextRecognitionService: TextRecognitionService {
        func recognizeText(in imageData: Data, usesLanguageCorrection: Bool) async throws -> String { "" }
        func currentRecognitionLanguage() -> String { "tr-TR" }
    }

    private func makeViewModel(
        savedIngredientsTextRepository: MockSavedIngredientsTextRepository,
        scanHistoryRepository: MockScanHistoryRepository = MockScanHistoryRepository(),
        context: IngredientsScanContext? = nil,
        onSuccessfulCheck: (() -> Void)? = nil
    ) -> IngredientsScanViewModel {
        IngredientsScanViewModel(
            textRecognitionService: StubTextRecognitionService(),
            profileRepository: MockUserProfileRepository(),
            savedIngredientsTextRepository: savedIngredientsTextRepository,
            scanHistoryRepository: scanHistoryRepository,
            context: context,
            onSuccessfulCheck: onSuccessfulCheck
        )
    }

    @Test("Barkod biliniyorsa, kontrol başarılı olunca metin barkod hafızasına kaydedilir")
    func checkTextSavesToMemoryWhenBarcodeKnown() {
        let repository = MockSavedIngredientsTextRepository()
        let context = IngredientsScanContext(
            barcode: "123",
            productName: "Test Ürünü",
            brand: "Marka",
            imageURL: URL(string: "https://example.com/image.jpg"),
            categories: ["yogurts"]
        )
        let viewModel = makeViewModel(savedIngredientsTextRepository: repository, context: context)
        viewModel.extractedText = "süt tozu, şeker"
        viewModel.hasIngredientsHeading = true

        viewModel.checkText()

        #expect(repository.savedRecords.count == 1)
        let saved = repository.savedRecords.first
        #expect(saved?.barcode == "123")
        #expect(saved?.productName == "Test Ürünü")
        #expect(saved?.brand == "Marka")
        #expect(saved?.categories == ["yogurts"])
        #expect(saved?.ingredientsText == "süt tozu, şeker")
        #expect(saved?.headingFound == true)
    }

    @Test("Başlık bulunamadıysa (headingFound=false) kayıt da bunu taşır")
    func checkTextSavesHeadingFoundFalse() {
        let repository = MockSavedIngredientsTextRepository()
        let context = IngredientsScanContext(barcode: "456", productName: nil, brand: nil, imageURL: nil, categories: [])
        let viewModel = makeViewModel(savedIngredientsTextRepository: repository, context: context)
        viewModel.extractedText = "su, şeker"
        viewModel.hasIngredientsHeading = false

        viewModel.checkText()

        #expect(repository.savedRecords.first?.headingFound == false)
    }

    @Test("Barkod bilinmiyorsa (doğrudan Fotoğrafla) hiçbir kayıt yapılmaz")
    func checkTextDoesNotSaveWhenNoBarcode() {
        let repository = MockSavedIngredientsTextRepository()
        let viewModel = makeViewModel(savedIngredientsTextRepository: repository, context: nil)
        viewModel.extractedText = "su, şeker"

        viewModel.checkText()

        #expect(repository.savedRecords.isEmpty)
    }

    @Test("Bağlamda barkod boş string ise de kayıt yapılmaz")
    func checkTextDoesNotSaveWhenBarcodeIsEmpty() {
        let repository = MockSavedIngredientsTextRepository()
        let context = IngredientsScanContext(barcode: "", productName: nil, brand: nil, imageURL: nil, categories: [])
        let viewModel = makeViewModel(savedIngredientsTextRepository: repository, context: context)
        viewModel.extractedText = "su, şeker"

        viewModel.checkText()

        #expect(repository.savedRecords.isEmpty)
    }

    @Test("'Tüm metni göster' açıkken kaydedilen metin fullRecognizedText olur")
    func checkTextSavesFullTextWhenToggled() {
        let repository = MockSavedIngredientsTextRepository()
        let context = IngredientsScanContext(barcode: "789", productName: nil, brand: nil, imageURL: nil, categories: [])
        let viewModel = makeViewModel(savedIngredientsTextRepository: repository, context: context)
        viewModel.extractedText = "ayıklanmış"
        viewModel.fullRecognizedText = "tüm okunan metin"
        viewModel.isShowingFullText = true

        viewModel.checkText()

        #expect(repository.savedRecords.first?.ingredientsText == "tüm okunan metin")
    }

    // MARK: - Adım D: tarama geçmişi kaydı

    @Test("Kontrol başarılı olunca sonuç geçmişe kaydedilir (kaynak: ocrPhoto)")
    func checkTextLogsToHistory() {
        let scanHistoryRepository = MockScanHistoryRepository()
        let context = IngredientsScanContext(barcode: "123", productName: "Test Ürünü", brand: "Marka", imageURL: nil, categories: ["yogurts"])
        let viewModel = makeViewModel(
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(),
            scanHistoryRepository: scanHistoryRepository,
            context: context
        )
        viewModel.extractedText = "süt tozu, şeker"
        viewModel.hasIngredientsHeading = true

        viewModel.checkText()

        #expect(scanHistoryRepository.savedEntries.count == 1)
        #expect(scanHistoryRepository.savedEntries.first?.source == .ocrPhoto)
        #expect(scanHistoryRepository.savedEntries.first?.barcode == "123")
        #expect(scanHistoryRepository.savedEntries.first?.snapshotStatus == .unsafe)
    }

    @Test("Barkod olmadan (doğrudan Fotoğrafla) da kontrol sonucu geçmişe kaydedilir")
    func checkTextLogsToHistoryEvenWithoutBarcode() {
        let scanHistoryRepository = MockScanHistoryRepository()
        let viewModel = makeViewModel(
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(),
            scanHistoryRepository: scanHistoryRepository,
            context: nil
        )
        viewModel.extractedText = "su, şeker"
        viewModel.hasIngredientsHeading = true

        viewModel.checkText()

        #expect(scanHistoryRepository.savedEntries.count == 1)
        #expect(scanHistoryRepository.savedEntries.first?.barcode == nil)
        #expect(scanHistoryRepository.savedEntries.first?.source == .ocrPhoto)
    }

    @Test("Kontrol başarılı olunca, bekleyen bir 'ara' kaydı artık gereksiz olduğunu bildiren geri çağırım tetiklenir")
    func checkTextInvokesOnSuccessfulCheck() {
        var callbackFired = false
        let context = IngredientsScanContext(barcode: "123", productName: nil, brand: nil, imageURL: nil, categories: [])
        let viewModel = makeViewModel(
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(),
            context: context,
            onSuccessfulCheck: { callbackFired = true }
        )
        viewModel.extractedText = "su, şeker"

        viewModel.checkText()

        #expect(callbackFired == true)
    }
}
