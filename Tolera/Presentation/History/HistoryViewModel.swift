import Foundation
import Observation

/// Tek bir geçmiş satırı: kayıt, güncel profille yeniden hesaplanmış sonuç, ve
/// `entry.snapshotStatus` ile bu güncel sonucun farklı olup olmadığı. `result.status`
/// listede gösterilecek TEK durumdur; `entry.snapshotStatus` (tarama anının donmuş
/// görüntüsü) asla doğrudan gösterilmemeli — bkz. `HistoryViewModel` üzerindeki not.
struct HistoryRow: Identifiable {
    var id: UUID { entry.id }
    let entry: ScanHistoryEntry
    let result: ProductCheckResult
    let statusChanged: Bool
}

/// Aynı güne ait satırların grubu, en yeni kayıt önce sıralı.
struct HistoryDayGroup: Identifiable {
    var id: Date { day }
    let day: Date
    let rows: [HistoryRow]
}

/// Tarama geçmişi ekranının ViewModel'i. Temkinli ilke: listede HER ZAMAN güncel kullanıcı
/// profiliyle yeniden hesaplanan sonuç gösterilir, kayıt anındaki `snapshotStatus` hiçbir
/// zaman doğrudan gösterilmez — aksi halde profil değiştikten sonra eski "safe" bir
/// kayıt yanıltıcı kalabilir (bkz. `RecheckScanHistoryEntryUseCase`, `CheckProductUseCase`
/// içindeki `isProfileEmpty`/`unknownDueToMissingOfficialData` kuralları).
@Observable
@MainActor
final class HistoryViewModel {
    private(set) var dayGroups: [HistoryDayGroup] = []

    private let scanHistoryRepository: ScanHistoryRepository
    private let profileRepository: UserProfileRepository
    private let recheckUseCase: RecheckScanHistoryEntryUseCase

    init(
        scanHistoryRepository: ScanHistoryRepository,
        profileRepository: UserProfileRepository,
        recheckUseCase: RecheckScanHistoryEntryUseCase = RecheckScanHistoryEntryUseCase()
    ) {
        self.scanHistoryRepository = scanHistoryRepository
        self.profileRepository = profileRepository
        self.recheckUseCase = recheckUseCase
    }

    func load() {
        let userAllergens = profileRepository.loadAllergens()
        let customTerms = profileRepository.loadCustomTerms()

        let rows = scanHistoryRepository.all().map { entry -> HistoryRow in
            let result = recheckUseCase.execute(entry: entry, userAllergens: userAllergens, customTerms: customTerms)
            return HistoryRow(entry: entry, result: result, statusChanged: result.status != entry.snapshotStatus)
        }

        let groupedByDay = Dictionary(grouping: rows) { Calendar.current.startOfDay(for: $0.entry.scannedAt) }
        dayGroups = groupedByDay
            .map { day, rows in
                HistoryDayGroup(day: day, rows: rows.sorted { $0.entry.scannedAt > $1.entry.scannedAt })
            }
            .sorted { $0.day > $1.day }
    }

    func delete(id: UUID) {
        scanHistoryRepository.delete(id: id)
        load()
    }

    func deleteAll() {
        scanHistoryRepository.deleteAll()
        load()
    }
}
