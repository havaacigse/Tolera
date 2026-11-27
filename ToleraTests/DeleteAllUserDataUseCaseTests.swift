import Foundation
import Testing
@testable import Tolera

/// "Tüm verilerimi sil" davranışını test eder: barkod hafızası, tarama geçmişi ve profil
/// (alerjenler/özel terimler/isim/onboarding bayrağı) sıfırlanmalı. Repository'ler sahte
/// (mock) implementasyonlarla izole edilir.
struct DeleteAllUserDataUseCaseTests {
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
        private(set) var entries: [ScanHistoryEntry]

        init(entries: [ScanHistoryEntry] = []) {
            self.entries = entries
        }

        func save(_ entry: ScanHistoryEntry) { entries.append(entry) }
        func all() -> [ScanHistoryEntry] { entries }
        func delete(id: UUID) { entries.removeAll { $0.id == id } }
        func deleteAll() { entries.removeAll() }
    }

    private final class MockUserProfileRepository: UserProfileRepository, @unchecked Sendable {
        var allergens: Set<Allergen>
        var customTerms: [String]
        var name: String?
        var onboardingCompleted: Bool

        init(
            allergens: Set<Allergen> = [.milk],
            customTerms: [String] = ["çilek"],
            name: String? = "Ayşe",
            onboardingCompleted: Bool = true
        ) {
            self.allergens = allergens
            self.customTerms = customTerms
            self.name = name
            self.onboardingCompleted = onboardingCompleted
        }

        func loadAllergens() -> Set<Allergen> { allergens }
        func save(allergens: Set<Allergen>) { self.allergens = allergens }
        func loadName() -> String? { name }
        func save(name: String) { self.name = name }
        func hasCompletedOnboarding() -> Bool { onboardingCompleted }
        func setOnboardingCompleted() { onboardingCompleted = true }
        func loadCustomTerms() -> [String] { customTerms }
        func save(customTerms: [String]) { self.customTerms = customTerms }

        /// Gerçek `UserProfileRepositoryImpl.resetAll()`'ı taklit eder: `removeObject`
        /// (yani "hiç değer yok") davranışını, isim ve onboarding bayrağı için `nil`/`false`
        /// ile temsil eder.
        func resetAll() {
            allergens = []
            customTerms = []
            name = nil
            onboardingCompleted = false
        }
    }

    private func makeSavedRecord(barcode: String) -> SavedIngredientsText {
        SavedIngredientsText(
            barcode: barcode,
            productName: "Ürün",
            brand: nil,
            imageURL: nil,
            categories: [],
            ingredientsText: "su, şeker",
            headingFound: true,
            savedAt: Date()
        )
    }

    private func makeHistoryEntry() -> ScanHistoryEntry {
        ScanHistoryEntry(
            barcode: "123",
            productName: "Ürün",
            brand: nil,
            imageURL: nil,
            ingredientsText: "su, şeker",
            allergens: [],
            traces: [],
            categories: [],
            type: .food,
            headingFound: true,
            source: .off,
            snapshotStatus: .safe
        )
    }

    @Test("Use case çalıştıktan sonra hafıza, geçmiş ve profil boş olur, onboarding bayrağı false olur")
    func executeClearsAllPersistedDataAndOnboardingFlag() {
        let savedRepository = MockSavedIngredientsTextRepository(preloaded: [makeSavedRecord(barcode: "123")])
        let historyRepository = MockScanHistoryRepository(entries: [makeHistoryEntry()])
        let profileRepository = MockUserProfileRepository()
        let useCase = DeleteAllUserDataUseCase(
            savedIngredientsTextRepository: savedRepository,
            scanHistoryRepository: historyRepository,
            userProfileRepository: profileRepository
        )

        useCase.execute()

        #expect(savedRepository.all().isEmpty)
        #expect(historyRepository.all().isEmpty)
        #expect(profileRepository.loadAllergens().isEmpty)
        #expect(profileRepository.loadCustomTerms().isEmpty)
        #expect(profileRepository.loadName() == nil)
        #expect(profileRepository.hasCompletedOnboarding() == false)
    }

    @Test("Silme sonrası bir ürün kontrol edildiğinde sonuç .safe olmaz (boş profil koruması)")
    func afterDeletionCheckingAProductNeverReturnsSafe() {
        let profileRepository = MockUserProfileRepository()
        let useCase = DeleteAllUserDataUseCase(
            savedIngredientsTextRepository: MockSavedIngredientsTextRepository(),
            scanHistoryRepository: MockScanHistoryRepository(),
            userProfileRepository: profileRepository
        )

        useCase.execute()

        let product = Product(
            barcode: "123",
            name: "Ürün",
            brand: nil,
            imageURL: nil,
            ingredientsText: "su, şeker",
            allergens: [],
            traces: [],
            categories: [],
            type: .food
        )
        let result = CheckProductUseCase().execute(
            product: product,
            userAllergens: profileRepository.loadAllergens(),
            customTerms: profileRepository.loadCustomTerms()
        )

        #expect(result.status != .safe)
    }
}
