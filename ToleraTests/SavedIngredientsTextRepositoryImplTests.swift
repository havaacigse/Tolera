import Foundation
import SwiftData
import Testing
@testable import Tolera

@Suite(.serialized)
@MainActor
struct SavedIngredientsTextRepositoryImplTests {
    // Her çağrı kendi, benzersiz adlı in-memory container'ını kurar; aynı process
    // içinde aynı @Model şemasıyla art arda container oluşturmak isim paylaşırsa
    // çökebiliyor, bu yüzden her testin kendi izole deposu olsun diye benzersiz isim verilir.
    // `container` burada yerel bir değişken olsa da artık güvenli: repository artık
    // container'ın kendisini saklıyor (bkz. SavedIngredientsTextRepositoryImpl), bu
    // fonksiyon dönünce `container`'ı tutan tek şey repository'nin kendisi olur.
    private func makeRepository() -> SavedIngredientsTextRepositoryImpl {
        let schema = Schema([SavedIngredientsTextModel.self, ScanHistoryEntryModel.self])
        let configuration = ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return SavedIngredientsTextRepositoryImpl(modelContainer: container)
    }

    private func makeRecord(
        barcode: String = "123",
        ingredientsText: String = "su, şeker",
        rawText: String? = nil
    ) -> SavedIngredientsText {
        SavedIngredientsText(
            barcode: barcode,
            productName: "Test Ürün",
            brand: "Marka",
            imageURL: URL(string: "https://example.com/image.jpg"),
            categories: ["yogurts"],
            ingredientsText: ingredientsText,
            rawText: rawText,
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

    @Test("rawText alanı opsiyonel: hem nil hem dolu değerle sorunsuz kaydedilip okunur")
    func rawTextFieldRoundTrips() {
        let repository = makeRepository()
        repository.save(makeRecord(barcode: "111", rawText: nil))
        repository.save(makeRecord(barcode: "222", rawText: "Alerjen uyarısı: Fındık içerebilir."))

        #expect(repository.find(barcode: "111")?.rawText == nil)
        #expect(repository.find(barcode: "222")?.rawText == "Alerjen uyarısı: Fındık içerebilir.")
    }

    /// Şema göçü (migration) güvenliği: `rawText` eklenmeden önce kaydedilmiş satırlar,
    /// bu alan `nil` olarak gelir (SwiftData'nın yeni OPSİYONEL bir alan eklemeyi otomatik
    /// desteklediği, dokümante edilmiş "lightweight migration" durumu — yeni bir
    /// `VersionedSchema`/migration planı gerekmez). Gerçek bir "eski ikili dosyayı yeni
    /// şemayla açma" senaryosunu bu hızlı birim testinde tam olarak simüle etmek pratik
    /// değil (gerçek bir eski .sqlite fixture'ı gerektirir); burada doğrulanan, bu alanın
    /// nil değerle (göç sonrası eski satırların hâli budur) hiçbir yerde çökmeden, doğru
    /// şekilde akıp gittiğidir — repository → domain dönüşümünün tamamı dahil.
    @Test("rawText eklenmeden önceki satırları temsil eden nil değer, tüm okuma/kontrol akışında sorunsuz çalışır")
    func nilRawTextDoesNotCrashAnywhereInTheReadPath() {
        let repository = makeRepository()
        repository.save(makeRecord(barcode: "333", rawText: nil))

        let found = repository.find(barcode: "333")
        #expect(found != nil)
        #expect(found?.rawText == nil)

        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(
            rawText: found!.ingredientsText,
            userAllergens: [.milk],
            customTerms: [],
            headingFound: found!.headingFound,
            fullRawText: found!.rawText
        )
        #expect(result.status == .safe)
    }

    // Regresyon testi: container'ı sadece yerel bir değişkende oluşturup repository'ye
    // veren bir yardımcı fonksiyon — tam olarak önceki EXC_BREAKPOINT çökmesine yol açan
    // kalıp. Repository artık container'ı kendisi sakladığından (çağıran tarafın ayrıca
    // canlı tutmasına gerek kalmadan), fonksiyon bittikten sonra da save/fetch çalışmalı.
    @Test("Container'ı oluşturan yerel değişken scope dışına çıksa bile repository çalışmayı sürdürür")
    func repositoryOutlivesLocalContainerVariable() {
        func makeRepositoryFromLocalContainer() -> SavedIngredientsTextRepositoryImpl {
            let schema = Schema([SavedIngredientsTextModel.self, ScanHistoryEntryModel.self])
            let configuration = ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
            let localContainer = try! ModelContainer(for: schema, configurations: [configuration])
            return SavedIngredientsTextRepositoryImpl(modelContainer: localContainer)
        }

        let repository = makeRepositoryFromLocalContainer()
        repository.save(makeRecord())

        #expect(repository.find(barcode: "123")?.ingredientsText == "su, şeker")
    }
}
