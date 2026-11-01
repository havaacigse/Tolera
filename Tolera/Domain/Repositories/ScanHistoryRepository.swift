import Foundation

/// Tüm taramaların değişmez geçmişi. Bkz. `ScanHistoryEntry`.
protocol ScanHistoryRepository {
    func save(_ entry: ScanHistoryEntry)
    /// Tarihe göre azalan (en yeni önce) sıralı döner.
    func all() -> [ScanHistoryEntry]
    func delete(id: UUID)
    func deleteAll()
}
