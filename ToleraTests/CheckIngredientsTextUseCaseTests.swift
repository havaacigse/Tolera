import Foundation
import Testing
@testable import Tolera

struct CheckIngredientsTextUseCaseTests {
    @Test func ocrTarziMetindeTireIleBolunenKelimeDogruAnalizEdilir() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "BUĞDAY UNU (GLUTEN), Şeker. FIN-\nDIK İÇEREBİLİR."

        let result = useCase.execute(rawText: rawText, userAllergens: [.gluten, .nuts], customTerms: [], headingFound: true)

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.gluten))
        #expect(result.matchedTraces.contains(.nuts))
    }

    /// OCR'da nokta kaybolup "eser miktar" uyarısı önceki cümleyle (virgülle) birleşirse,
    /// hangi kelimenin eser miktar hangisinin içerik olduğu belirsizleşir; temkinli ilke
    /// gereği (contains > mayContain) ikisi de içerik sayılır — mayContain'e düşürülmez.
    @Test func noktalamaKaybolanOcrMetnindeTemkinliIlkeIkisiniDeIcerikSayar() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "BUĞDAY UNU (GLUTEN), Şeker, FINDIK İÇEREBİLİR."

        let result = useCase.execute(rawText: rawText, userAllergens: [.gluten, .nuts], customTerms: [], headingFound: true)

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.gluten))
        #expect(result.matchedAllergens.contains(.nuts))
        #expect(result.matchedTraces.isEmpty)
    }

    @Test func bosProfilIleIsProfileEmptyDoner() {
        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(rawText: "şeker, su", userAllergens: [], customTerms: [], headingFound: true)

        #expect(result.isProfileEmpty)
    }

    @Test func uretilenUrunKategorisizVeBarkodsuzdur() {
        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(rawText: "su, şeker", userAllergens: [.milk], customTerms: [], headingFound: true)

        #expect(result.product.categories.isEmpty)
        #expect(result.product.barcode.isEmpty)
    }

    /// Barkod hafızasından (SavedIngredientsTextRepository) servis edilen bir sonuç için
    /// barkod/marka/görsel/kategori bilgisi de taşınabilmeli (ör. alternatif önerisi ileride
    /// bu bilgiyi kullanabilsin).
    @Test func barkodVeOffBilgisiVerilirseUrunTasinir() {
        let useCase = CheckIngredientsTextUseCase()
        let imageURL = URL(string: "https://example.com/image.jpg")!
        let result = useCase.execute(
            rawText: "su, şeker",
            userAllergens: [.milk],
            customTerms: [],
            headingFound: true,
            barcode: "123",
            brand: "Marka",
            imageURL: imageURL,
            categories: ["yogurts"]
        )

        #expect(result.product.barcode == "123")
        #expect(result.product.brand == "Marka")
        #expect(result.product.imageURL == imageURL)
        #expect(result.product.categories == ["yogurts"])
    }

    @Test func ozelTerimIcerenMetindeEslesir() {
        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(rawText: "mısır nişastası, su", userAllergens: [], customTerms: ["mısır"], headingFound: true)

        #expect(result.status == .unsafe)
        #expect(result.matchedCustomTerms == ["mısır"])
    }

    // MARK: - Başlık bulunamazsa sonuç asla "safe" olamaz (temkinli ilke)

    /// Gerçek cihaz hatası: OCR içindekiler yerine üretim yeri/adres metnini okudu ve
    /// hiçbir alerjen kelimesi eşleşmediği için sonuç "safe" dönmüştü. "İçindekiler"
    /// başlığı bulunamadığında bu artık mümkün değil: sonuç "unknown"a çevrilir.
    @Test func basliksizUretimYeriMetninSuTAlerjisindeSafeDegilUnknownDoner() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "Üretim yeri: Konya, Türkiye. Net 500 g. Son tüketim tarihi..."

        let result = useCase.execute(rawText: rawText, userAllergens: [.milk], customTerms: [], headingFound: false)

        #expect(result.status == .unknown)
        #expect(result.isMissingIngredientsHeading)
    }

    /// Başlık bulunamasa da metinde gerçekten alerjen kelimesi eşleştiyse (ör. "yoğurt")
    /// bu geçerliliğini korur; temkinli ilke sadece "safe"i engeller, "unsafe"i gizlemez.
    @Test func basliksizMetindeAlerjenEslesirseUnsafeKalir() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "Süzme yoğurt, net 500 g"

        let result = useCase.execute(rawText: rawText, userAllergens: [.milk], customTerms: [], headingFound: false)

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.milk))
        #expect(!result.isMissingIngredientsHeading)
    }

    @Test func basliklaBulunanMetindeAlerjenEslesirseUnsafeDoner() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "İçindekiler: pastörize inek sütü, yoğurt kültürü"

        let result = useCase.execute(rawText: rawText, userAllergens: [.milk], customTerms: [], headingFound: true)

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.milk))
    }

    /// Başlık bulunduğunda ve içinde hiç alerjen yoksa "safe" geçerliliğini korur —
    /// kısıtlama sadece başlık BULUNAMADIĞINDA devreye girer.
    @Test func basliklaBulunanAlerjensizMetinSafeKalir() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "İçindekiler: su, şeker, tuz"

        let result = useCase.execute(rawText: rawText, userAllergens: [.milk], customTerms: [], headingFound: true)

        #expect(result.status == .safe)
        #expect(!result.isMissingIngredientsHeading)
    }
}
