import Foundation
import SwiftData

final class SavedIngredientsTextRepositoryImpl: SavedIngredientsTextRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func find(barcode: String) -> SavedIngredientsText? {
        existingModel(forBarcode: barcode)?.toDomain()
    }

    /// Aynı barkod için zaten bir kayıt varsa üzerine yazar ("Yeniden oku"); yoksa yeni ekler.
    func save(_ record: SavedIngredientsText) {
        if let existing = existingModel(forBarcode: record.barcode) {
            existing.update(from: record)
        } else {
            modelContext.insert(SavedIngredientsTextModel(from: record))
        }
        try? modelContext.save()
    }

    func delete(barcode: String) {
        guard let existing = existingModel(forBarcode: barcode) else { return }
        modelContext.delete(existing)
        try? modelContext.save()
    }

    func all() -> [SavedIngredientsText] {
        let descriptor = FetchDescriptor<SavedIngredientsTextModel>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor))?.map { $0.toDomain() } ?? []
    }

    // `#Predicate` makrosu bu veri boyutu için gereksiz; kayıt sayısı (tek kullanıcının
    // kendi cihazındaki barkod hafızası) zaten küçük olduğundan tümünü çekip Swift'te
    // filtrelemek hem daha basit hem de makro ile ilgili olası sürüm sorunlarından bağımsız.
    private func existingModel(forBarcode targetBarcode: String) -> SavedIngredientsTextModel? {
        let all = (try? modelContext.fetch(FetchDescriptor<SavedIngredientsTextModel>())) ?? []
        return all.first { $0.barcode == targetBarcode }
    }
}
