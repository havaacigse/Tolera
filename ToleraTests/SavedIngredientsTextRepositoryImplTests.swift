import Foundation
import SwiftData
import Testing
@testable import Tolera

@MainActor
struct SavedIngredientsTextRepositoryImplTests {
    // Her çağrı kendi, benzersiz adlı in-memory container'ını kurar; aynı process
    // içinde aynı @Model şemasıyla art arda container oluşturmak isim paylaşırsa
    // çökebiliyor, bu yüzden her testin kendi izole deposu olsun diye benzersiz isim verilir.
    private func makeRepository() -> SavedIngredientsTextRepositoryImpl {
        let schema = Schema([SavedIngredientsTextModel.self, ScanHistoryEntryModel.self])
        let configuration = ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return SavedIngredientsTextRepositoryImpl(modelContext: container.mainContext)
    }

    private func makeRecord(barcode: String = "123", ingredientsText: String = "su, şeker") -> SavedIngredientsText {
        SavedIngredientsText(
            barcode: barcode,
            productName: "Test Ürün",
            brand: "Marka",
            imageURL: URL(string: "https://example.com/image.jpg"),
            categories: ["yogurts"],
            ingredientsText: ingredientsText,
            headingFound: true,
            savedAt: Date()
        )
    }

    @Test("Kaydedilen metin aynı barkodla bulunur")
    func savedRecordIsFoundByBarcode() {
        let repository = makeRepository()
        repository.save(makeRecord())

        let found = repository.find(barcode: "123")

        #expect(found?.ingredientsText == "su, şeker")
        #expect(found?.brand == "Marka")
        #expect(found?.categories == ["yogurts"])
    }

    @Test("Olmayan barkod için nil döner")
    func unknownBarcodeReturnsNil() {
        let repository = makeRepository()
        #expect(repository.find(barcode: "999") == nil)
    }

    @Test("Aynı barkod yeniden kaydedilirse (Yeniden oku) üzerine yazılır, ikinci satır eklenmez")
    func resavingSameBarcodeOverwritesInsteadOfDuplicating() {
        let repository = makeRepository()
        repository.save(makeRecord(ingredientsText: "eski metin"))
        repository.save(makeRecord(ingredientsText: "yeni metin"))

        #expect(repository.find(barcode: "123")?.ingredientsText == "yeni metin")
        #expect(repository.all().count == 1)
    }

    @Test("Silinen barkod artık bulunamaz")
    func deletedRecordIsNoLongerFound() {
        let repository = makeRepository()
        repository.save(makeRecord())

        repository.delete(barcode: "123")

        #expect(repository.find(barcode: "123") == nil)
        #expect(repository.all().isEmpty)
    }

    @Test("all() tüm kayıtlı barkodları döner")
    func allReturnsEveryRecord() {
        let repository = makeRepository()
        repository.save(makeRecord(barcode: "111"))
        repository.save(makeRecord(barcode: "222"))

        #expect(repository.all().count == 2)
    }
}
