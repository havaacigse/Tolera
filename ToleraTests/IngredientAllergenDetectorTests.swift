import Testing
@testable import Tolera

struct IngredientAllergenDetectorTests {
    private let detector = IngredientAllergenDetector()

    @Test("buğday unu glüten olarak yakalanır")
    func wheatFlourDetectsGluten() {
        let result = detector.detect(in: "buğday unu, şeker")
        #expect(result == [.gluten])
    }

    @Test("büyük harfli ve Türkçe İ içeren süt ifadeleri yakalanır")
    func uppercaseTurkishTextDetectsMilk() {
        let result = detector.detect(in: "SÜT TOZU, İNEK SÜTÜ")
        #expect(result == [.milk])
    }

    @Test("\"sütlü\" kelimesi süt alerjeni olarak yakalanır")
    func sutluWordDetectsMilk() {
        let result = detector.detect(in: "sütlü çikolata")
        #expect(result == [.milk])
    }

    @Test("\"fındığı\" çekimli hali sert kabuklu yemiş olarak yakalanır")
    func findigiInflectedFormDetectsNuts() {
        let result = detector.detect(in: "fındığı ezilmiş")
        #expect(result == [.nuts])
    }

    @Test("kaymak ve süt birlikte geçtiğinde süt alerjeni döner")
    func kaymakAndMilkDetectMilk() {
        let result = detector.detect(in: "kaymağı alınmış süt")
        #expect(result == [.milk])
    }

    @Test("\"ton balığı\" ifadesi balık alerjeni olarak yakalanır")
    func tunaFishDetectsFish() {
        let result = detector.detect(in: "ton balığı, zeytinyağı")
        #expect(result == [.fish])
    }

    @Test("\"hindistan cevizi\" istisnadır, alerjen sayılmaz")
    func coconutIsException() {
        let result = detector.detect(in: "hindistan cevizi")
        #expect(result.isEmpty)
    }

    @Test("\"hindistan cevizi sütü\" süt alerjeni sayılmaz")
    func coconutMilkIsNotDairy() {
        let result = detector.detect(in: "hindistan cevizi sütü")
        #expect(result.isEmpty)
    }

    @Test("\"badem sütü\" süt değil, sert kabuklu yemiş olarak yakalanır")
    func almondMilkDetectsNutsNotMilk() {
        let result = detector.detect(in: "badem sütü")
        #expect(result == [.nuts])
    }

    @Test("\"maltodekstrin\" gluten alerjeni olarak yanlış yakalanmaz")
    func maltodextrinDoesNotTriggerGluten() {
        let result = detector.detect(in: "maltodekstrin, şeker")
        #expect(result.isEmpty)
    }

    @Test("\"arpa maltı\" gluten alerjeni olarak yakalanır")
    func barleyMaltDetectsGluten() {
        let result = detector.detect(in: "arpa maltı")
        #expect(result == [.gluten])
    }

    @Test("E220 kodu sülfit alerjeni olarak yakalanır")
    func e220CodeDetectsSulphites() {
        let result = detector.detect(in: "koruyucu (E220)")
        #expect(result == [.sulphites])
    }

    @Test("alerjen içermeyen bir metinde hiçbir alerjen bulunmaz")
    func plainTextHasNoAllergens() {
        let result = detector.detect(in: "su, şeker, tuz")
        #expect(result.isEmpty)
    }

    @Test("birden fazla alerjen aynı metinde birlikte yakalanır")
    func multipleAllergensDetectedTogether() {
        let result = detector.detect(in: "yumurta, susam, soya lesitini")
        #expect(result == [.eggs, .sesame, .soybeans])
    }

    @Test("\"antep fıstığı\" sert kabuklu yemiştir, yer fıstığı sayılmaz")
    func antepPistachioDetectsNutsNotPeanuts() {
        let result = detector.detect(in: "antep fıstığı içerir")
        #expect(result == [.nuts])
    }

    @Test("\"antep fıstıklı baklava\" sert kabuklu yemiştir, yer fıstığı sayılmaz")
    func antepPistachioAdjectiveFormDetectsNutsNotPeanuts() {
        let result = detector.detect(in: "antep fıstıklı baklava")
        #expect(result == [.nuts])
    }

    @Test("\"fıstıklı\" (antep öneki olmadan) yer fıstığı olarak yakalanır")
    func bareFistikliDetectsPeanuts() {
        let result = detector.detect(in: "fıstıklı çikolata")
        #expect(result == [.peanuts])
    }
}
