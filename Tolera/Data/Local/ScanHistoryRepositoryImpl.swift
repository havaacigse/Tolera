import Foundation
import SwiftData

/// `ModelContext` yerine `ModelContainer`'ın kendisi saklanır — bkz.
/// `SavedIngredientsTextRepositoryImpl`'deki açıklama (aynı EXC_BREAKPOINT çökmesinin
/// aynı kök sebebi). `mainContext` erişimi @MainActor gerektirdiğinden sınıf da
/// @MainActor işaretli.
@MainActor
final class ScanHistoryRepositoryImpl: ScanHistoryRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func save(_ entry: ScanHistoryEntry) {
        modelContext.insert(ScanHistoryEntryModel(from: entry))
        try? modelContext.save()
    }

    func all() -> [ScanHistoryEntry] {
        let descriptor = FetchDescriptor<ScanHistoryEntryModel>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor))?.map { $0.toDomain() } ?? []
    }

    // `#Predicate` makrosu bu veri boyutu için gereksiz; bkz.
    // `SavedIngredientsTextRepositoryImpl.existingModel`.
    func delete(id targetId: UUID) {
        let all = (try? modelContext.fetch(FetchDescriptor<ScanHistoryEntryModel>())) ?? []
        guard let existing = all.first(where: { $0.id == targetId }) else { return }
        modelContext.delete(existing)
        try? modelContext.save()
    }

    func deleteAll() {
        guard let all = try? modelContext.fetch(FetchDescriptor<ScanHistoryEntryModel>()) else { return }
        for model in all {
            modelContext.delete(model)
        }
        try? modelContext.save()
    }
}
