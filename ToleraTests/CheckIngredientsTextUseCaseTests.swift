import Testing
@testable import Tolera

struct CheckIngredientsTextUseCaseTests {
    @Test func ocrTarziMetindeTireIleBolunenKelimeDogruAnalizEdilir() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "BUĞDAY UNU (GLUTEN), Şeker. FIN-\nDIK İÇEREBİLİR."

        let result = useCase.execute(rawText: rawText, userAllergens: [.gluten, .nuts], customTerms: [])

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

        let result = useCase.execute(rawText: rawText, userAllergens: [.gluten, .nuts], customTerms: [])

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.gluten))
        #expect(result.matchedAllergens.contains(.nuts))
        #expect(result.matchedTraces.isEmpty)
    }

    @Test func bosProfilIleIsProfileEmptyDoner() {
        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(rawText: "şeker, su", userAllergens: [], customTerms: [])

        #expect(result.isProfileEmpty)
    }

    @Test func uretilenUrunKategorisizVeBarkodsuzdur() {
        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(rawText: "su, şeker", userAllergens: [.milk], customTerms: [])

        #expect(result.product.categories.isEmpty)
        #expect(result.product.barcode.isEmpty)
    }

    @Test func ozelTerimIcerenMetindeEslesir() {
        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(rawText: "mısır nişastası, su", userAllergens: [], customTerms: ["mısır"])

        #expect(result.status == .unsafe)
        #expect(result.matchedCustomTerms == ["mısır"])
    }
}
