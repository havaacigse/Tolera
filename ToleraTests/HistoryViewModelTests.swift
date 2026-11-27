import Foundation
import Testing
@testable import Tolera

/// `HistoryViewModel`'in temkinli ilke açısından en kritik davranışı: listede HER ZAMAN
/// güncel profille yeniden hesaplanan sonuç gösterilir, `snapshotStatus` (tarama anının
/// donmuş görüntüsü) asla direkt gösterilmez. Repository ve profil kaynağı sahte (mock)
/// implementasyonlarla izole edilir.
@MainActor
struct HistoryViewModelTests {
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
        var allergens: Set<Allergen> = []
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

    private func makeEntry(
        id: UUID = UUID(),
        productName: String = "Test Ürün",
        ingredientsText: String? = "su, şeker",
        allergens: Set<Allergen> = [],
        source: ScanSource = .off,
        headingFound: Bool = true,
        snapshotStatus: CheckStatus,
        scannedAt: Date
    ) -> ScanHistoryEntry {
        ScanHistoryEntry(
            id: id,
            barcode: "123",
            productName: productName,
            brand: nil,
            imageURL: nil,
            ingredientsText: ingredientsText,
            allergens: allergens,
            traces: [],
            categories: [],
            type: .food,
            headingFound: headingFound,
            source: source,
            snapshotStatus: snapshotStatus,
            scannedAt: scannedAt
        )
    }

    @Test("Snapshot .safe olan kayıt, profile süt eklendikten sonra .unsafe görünür ve statusChanged true olur")
    func statusUpdatesWhenProfileGainsMatchingAllergen() {
        let entry = makeEntry(allergens: [.milk], snapshotStatus: .safe, scannedAt: Date())
        let repository = MockScanHistoryRepository(entries: [entry])
        let profile = MockUserProfileRepository()
        profile.allergens = [.milk]
        let viewModel = HistoryViewModel(scanHistoryRepository: repository, profileRepository: profile)

        viewModel.load()

        let row = viewModel.dayGroups.first?.rows.first
        #expect(row?.result.status == .unsafe)
        #expect(row?.statusChanged == true)
    }

    @Test("Profil boşken .off ve .ocrPhoto kayıtlarının hiçbiri .safe görünmez")
    func emptyProfileNeverShowsSafe() {
        let offEntry = makeEntry(allergens: [.milk], source: .off, snapshotStatus: .safe, scannedAt: Date())
        let ocrEntry = makeEntry(
            allergens: [],
            source: .ocrPhoto,
            headingFound: true,
            snapshotStatus: .safe,
            scannedAt: Date().addingTimeInterval(-10)
        )
        let repository = MockScanHistoryRepository(entries: [offEntry, ocrEntry])
        let viewModel = HistoryViewModel(scanHistoryRepository: repository, profileRepository: MockUserProfileRepository())

        viewModel.load()

        let statuses = viewModel.dayGroups.flatMap(\.rows).map(\.result.status)
        #expect(!statuses.contains(.safe))
    }

    @Test("Sonucu değişmeyen kayıtta statusChanged false olur")
    func statusChangedIsFalseWhenResultMatchesSnapshot() {
        let entry = makeEntry(allergens: [], snapshotStatus: .safe, scannedAt: Date())
        let repository = MockScanHistoryRepository(entries: [entry])
        let profile = MockUserProfileRepository()
        profile.allergens = [.gluten]
        let viewModel = HistoryViewModel(scanHistoryRepository: repository, profileRepository: profile)

        viewModel.load()

        #expect(viewModel.dayGroups.first?.rows.first?.result.status == .safe)
        #expect(viewModel.dayGroups.first?.rows.first?.statusChanged == false)
    }

    @Test("Farklı günlerden 3 kayıt doğru gruplanır ve sıralanır: en yeni gün ve en yeni kayıt önce")
    func groupsAndOrdersAcrossDays() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let todayEarlier = makeEntry(productName: "Bugün Erken", snapshotStatus: .safe, scannedAt: today.addingTimeInterval(-3600))
        let todayLater = makeEntry(productName: "Bugün Son", snapshotStatus: .safe, scannedAt: today)
        let yesterdayEntry = makeEntry(productName: "Dün", snapshotStatus: .safe, scannedAt: yesterday)
        let oldEntry = makeEntry(productName: "İki Gün Önce", snapshotStatus: .safe, scannedAt: twoDaysAgo)

        let repository = MockScanHistoryRepository(entries: [oldEntry, yesterdayEntry, todayEarlier, todayLater])
        let viewModel = HistoryViewModel(scanHistoryRepository: repository, profileRepository: MockUserProfileRepository())

        viewModel.load()

        #expect(viewModel.dayGroups.count == 3)
        #expect(viewModel.dayGroups[0].rows.map(\.entry.productName) == ["Bugün Son", "Bugün Erken"])
        #expect(viewModel.dayGroups[1].rows.map(\.entry.productName) == ["Dün"])
        #expect(viewModel.dayGroups[2].rows.map(\.entry.productName) == ["İki Gün Önce"])
    }

    @Test("delete(id:) sonrası kayıt listeden çıkar, deleteAll() sonrası liste boş olur")
    func deleteAndDeleteAllUpdateList() {
        let first = makeEntry(productName: "Birinci", snapshotStatus: .safe, scannedAt: Date())
        let second = makeEntry(productName: "İkinci", snapshotStatus: .safe, scannedAt: Date().addingTimeInterval(-10))
        let repository = MockScanHistoryRepository(entries: [first, second])
        let viewModel = HistoryViewModel(scanHistoryRepository: repository, profileRepository: MockUserProfileRepository())
        viewModel.load()

        viewModel.delete(id: first.id)
        #expect(viewModel.dayGroups.flatMap { $0.rows }.map { $0.entry.id } == [second.id])

        viewModel.deleteAll()
        #expect(viewModel.dayGroups.isEmpty)
    }

    @Test("Repository boşsa liste boş olur ve çökmez")
    func emptyRepositoryProducesEmptyList() {
        let viewModel = HistoryViewModel(
            scanHistoryRepository: MockScanHistoryRepository(),
            profileRepository: MockUserProfileRepository()
        )

        viewModel.load()

        #expect(viewModel.dayGroups.isEmpty)
    }
}
