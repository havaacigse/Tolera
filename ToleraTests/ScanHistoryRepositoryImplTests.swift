import Foundation
import SwiftData
import Testing
@testable import Tolera

@MainActor
struct ScanHistoryRepositoryImplTests {
    // Her çağrı kendi, benzersiz adlı in-memory container'ını kurar; aynı process
    // içinde aynı @Model şemasıyla art arda container oluşturmak isim paylaşırsa
    // çökebiliyor, bu yüzden her testin kendi izole deposu olsun diye benzersiz isim verilir.
    private func makeRepository() -> ScanHistoryRepositoryImpl {
        let schema = Schema([SavedIngredientsTextModel.self, ScanHistoryEntryModel.self])
        let configuration = ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return ScanHistoryRepositoryImpl(modelContext: container.mainContext)
    }

    private func makeEntry(
        productName: String = "Test Ürün",
        source: ScanSource = .off,
        status: CheckStatus = .safe,
        scannedAt: Date = Date()
    ) -> ScanHistoryEntry {
        ScanHistoryEntry(
            barcode: "123",
            productName: productName,
            brand: "Marka",
            imageURL: URL(string: "https://example.com/image.jpg"),
            ingredientsText: "su, şeker",
            allergens: [.milk],
            traces: [],
            categories: ["yogurts"],
            type: .food,
            headingFound: true,
            source: source,
            snapshotStatus: status,
            scannedAt: scannedAt
        )
    }

    @Test("Kaydedilen girdi tüm alanlarıyla geri okunur")
    func savedEntryRoundTripsAllFields() {
        let repository = makeRepository()
        let entry = makeEntry()
        repository.save(entry)

        let all = repository.all()

        #expect(all.count == 1)
        #expect(all.first?.id == entry.id)
        #expect(all.first?.productName == "Test Ürün")
        #expect(all.first?.allergens == [.milk])
        #expect(all.first?.categories == ["yogurts"])
        #expect(all.first?.source == .off)
        #expect(all.first?.snapshotStatus == .safe)
    }

    @Test("all() en yeni tarama önce olacak şekilde sıralı döner")
    func allReturnsNewestFirst() {
        let repository = makeRepository()
        let older = makeEntry(productName: "Eski", scannedAt: Date(timeIntervalSinceNow: -3600))
        let newer = makeEntry(productName: "Yeni", scannedAt: Date())
        repository.save(older)
        repository.save(newer)

        let all = repository.all()

        #expect(all.map(\.productName) == ["Yeni", "Eski"])
    }

    @Test("Belirli bir girdi id'siyle silinebilir")
    func deleteByIdRemovesOnlyThatEntry() {
        let repository = makeRepository()
        let toDelete = makeEntry(productName: "Silinecek")
        let toKeep = makeEntry(productName: "Kalacak")
        repository.save(toDelete)
        repository.save(toKeep)

        repository.delete(id: toDelete.id)

        let all = repository.all()
        #expect(all.count == 1)
        #expect(all.first?.productName == "Kalacak")
    }

    @Test("deleteAll() tüm geçmişi temizler")
    func deleteAllClearsEverything() {
        let repository = makeRepository()
        repository.save(makeEntry(productName: "Bir"))
        repository.save(makeEntry(productName: "İki"))

        repository.deleteAll()

        #expect(repository.all().isEmpty)
    }

    @Test("OCR kaynaklı (ocrPhoto) girdi kaynağıyla birlikte doğru kaydedilir")
    func ocrSourcedEntryPreservesSource() {
        let repository = makeRepository()
        repository.save(makeEntry(source: .ocrPhoto))

        #expect(repository.all().first?.source == .ocrPhoto)
    }
}
