import Testing
@testable import Tolera

struct IngredientsSectionExtractorTests {
    @Test func basliklaBaslayanMetindeBaslikSonrasiAlinir() {
        let text = "MARKA LOGO\nİÇİNDEKİLER: Buğday unu, şeker, fındık.\nBESİN DEĞERLERİ\nEnerji: 400kcal"
        let result = IngredientsSectionExtractor.extract(from: text)
        #expect(result == "Buğday unu, şeker, fındık.")
    }

    @Test func basliksizMetindeTamaminiKullanir() {
        let text = "Buğday unu, şeker, fındık."
        let result = IngredientsSectionExtractor.extract(from: text)
        #expect(result == text)
    }

    @Test func basliksizAmaBesinTablosuVarsaKesilir() {
        let text = "Buğday unu, şeker, fındık. Besin değerleri: Enerji 400kcal"
        let result = IngredientsSectionExtractor.extract(from: text)
        #expect(result == "Buğday unu, şeker, fındık.")
    }

    @Test func buyukHarfliBaslikDaEslesir() {
        let text = "İÇİNDEKİLER: BUĞDAY UNU, ŞEKER"
        let result = IngredientsSectionExtractor.extract(from: text)
        #expect(result == "BUĞDAY UNU, ŞEKER")
    }

    @Test func ocrHatasiOlanBaslikDaEslesir() {
        let text = "İcindekiler: fındık, süt"
        let result = IngredientsSectionExtractor.extract(from: text)
        #expect(result == "fındık, süt")
    }

    @Test func ingilizceBaslikDaEslesir() {
        let text = "Ingredients: wheat flour, sugar"
        let result = IngredientsSectionExtractor.extract(from: text)
        #expect(result == "wheat flour, sugar")
    }

    @Test func nutritionBaslikliSonBolumDeKesilir() {
        let text = "İçindekiler: şeker, su Nutrition facts: 100kcal"
        let result = IngredientsSectionExtractor.extract(from: text)
        #expect(result == "şeker, su")
    }

    @Test func baslikVarsaHeadingFoundTrueDoner() {
        let text = "İÇİNDEKİLER: Buğday unu, şeker"
        #expect(IngredientsSectionExtractor.headingFound(in: text))
    }

    @Test func baslikYoksaHeadingFoundFalseDoner() {
        let text = "Üretim yeri: Konya, Türkiye. Net 500 g."
        #expect(!IngredientsSectionExtractor.headingFound(in: text))
    }

    /// Son nokta sadece sabit bir kelime listesiyle ("besin değerleri", "enerji" vb.)
    /// belirleniyor; içindekiler listesinin hemen ardından (besin tablosundan ÖNCE) gelen
    /// bir eser miktar uyarısı kesilmez, analize girer.
    @Test func icindekilerListesiSonrasiEserMiktarUyarisiBesinTablosundanOncekesilmez() {
        let text = "İçindekiler: buğday unu, şeker. Fındık içerebilir. Enerji: 520 kcal"
        let result = IngredientsSectionExtractor.extract(from: text)
        #expect(result.contains("Fındık içerebilir"))
        #expect(!result.contains("520 kcal"))
    }
}
