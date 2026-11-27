import Testing
@testable import Tolera

/// `IngredientAllergenDetector.detectWarningSentences(in:)` testleri. Gerçek cihaz riski:
/// `IngredientsSectionExtractor`, "içindekiler...besin değerleri" penceresinin DIŞINDA
/// (önce ya da sonra) yazılan alerjen uyarılarını (ör. "Alerjen uyarısı: X içerebilir",
/// "X ve Y işlenen tesiste üretilmiştir") kesip atıyor; normal `detect(in:)` bu metni hiç
/// görmediği için alerjen kaçırılabiliyor. Bu testler, ham OCR metninin TAMAMINI tarayan
/// ayrı bir yöntemin bu uyarıları doğru bulduğunu kanıtlıyor.
struct IngredientWarningSentenceDetectionTests {
    private let detector = IngredientAllergenDetector()

    @Test("Besin değerleri tablosundan SONRA gelen 'X içerebilir' uyarısı mayContain olarak bulunur")
    func warningAfterNutritionTableIsMayContain() {
        let text = "İçindekiler: şeker, kakao. Besin değerleri: Enerji 500 kcal. Alerjen uyarısı: Fındık içerebilir."
        let result = detector.detectWarningSentences(in: text)
        #expect(result.mayContain.contains(.nuts))
        #expect(!result.contains.contains(.nuts))
    }

    @Test("İçindekiler başlığından ÖNCE gelen 'X içerir' uyarısı contains olarak bulunur")
    func warningBeforeIngredientsHeadingIsContains() {
        let text = "Alerjen uyarısı: Süt içerir. İçindekiler: şeker, kakao."
        let result = detector.detectWarningSentences(in: text)
        #expect(result.contains.contains(.milk))
    }

    @Test("'İşlenen tesiste üretilmiştir' çapraz bulaşma ifadesi birden fazla alerjeni mayContain olarak bulur")
    func crossContaminationFacilityWarningIsMayContainForMultipleAllergens() {
        let text = "İçindekiler: şeker, kakao. Enerji 500 kcal. Bu ürün fındık ve susam işlenen tesiste üretilmiştir."
        let result = detector.detectWarningSentences(in: text)
        #expect(result.mayContain.contains(.nuts))
        #expect(result.mayContain.contains(.sesame))
    }

    @Test("Negatif kontrol: adres metnindeki 'Fındıklı'/'Susam' bir uyarı cümlesi değildir, hiçbir alerjen bulunmaz")
    func addressTextIsNotMistakenForWarningSentence() {
        let text = "İçindekiler: şeker, kakao. Besin değerleri: Enerji 500 kcal. Üretici: Fındıklı Mah. Susam Sok. No:5"
        let result = detector.detectWarningSentences(in: text)
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    // MARK: - Olumsuzlama: "X içermez" yanlış alarm vermemeli

    @Test("'Alerjen bilgisi: Gluten içermez.' yanlış alarm vermez")
    func glutenFreeDeclarationDoesNotFalsePositive() {
        let text = "Alerjen bilgisi: Gluten içermez."
        let result = detector.detectWarningSentences(in: text)
        #expect(!result.contains.contains(.gluten))
        #expect(!result.mayContain.contains(.gluten))
    }

    @Test("'Bu ürün süt içermez.' yanlış alarm vermez")
    func milkFreeDeclarationDoesNotFalsePositive() {
        let text = "Bu ürün süt içermez."
        let result = detector.detectWarningSentences(in: text)
        #expect(!result.contains.contains(.milk))
        #expect(!result.mayContain.contains(.milk))
    }

    @Test("'Gluten içermez, fındık içerebilir.' — olumsuzlama sadece kendi ifadesini etkiler, aynı cümledeki diğer uyarıyı bastırmaz")
    func negationDoesNotSuppressOtherClauseInSameSentence() {
        let text = "Gluten içermez, fındık içerebilir."
        let result = detector.detectWarningSentences(in: text)
        #expect(!result.contains.contains(.gluten))
        #expect(!result.mayContain.contains(.gluten))
        #expect(result.mayContain.contains(.nuts))
    }

    // MARK: - Virgülle ayrılmış liste: tetikleyici fiil/kelime SONDA/BAŞTA olsa da tüm liste etkilenmeli

    /// Risk: eğer tetikleyici tespiti virgülle bölünmüş her ifadeye AYRI AYRI uygulanırsa,
    /// sadece "süt ve susam içerebilir" ifadesi tetikleyici içerdiğinden fındık/badem atlanır.
    /// Tetikleyici cümle SEVİYESİNDE aranmalı, virgülle ayrılmış ifadeler sadece olumsuzlama
    /// (içermez) için ayrıştırılmalı.
    @Test("'Fındık, badem, süt ve susam içerebilir.' — tetikleyici fiil sonda olsa da listedeki HEPSİ mayContain olur")
    func trailingVerbAppliesToWholeCommaSeparatedList() {
        let text = "Fındık, badem, süt ve susam içerebilir."
        let result = detector.detectWarningSentences(in: text)
        #expect(result.mayContain.contains(.nuts))
        #expect(result.mayContain.contains(.milk))
        #expect(result.mayContain.contains(.sesame))
    }

    @Test("'Alerjen uyarısı: fındık, süt, yumurta.' — tetikleyici baştaki 'alerjen' kelimesiyse de listedeki HEPSİ yakalanır")
    func leadingTriggerWordAppliesToWholeCommaSeparatedList() {
        let text = "Alerjen uyarısı: fındık, süt, yumurta."
        let result = detector.detectWarningSentences(in: text)
        #expect(result.contains.contains(.nuts))
        #expect(result.contains.contains(.milk))
        #expect(result.contains.contains(.eggs))
    }

    @Test("'Eser miktarda fındık, yer fıstığı içerebilir.' — iki ayrı tetikleyici içeren liste de tamamen yakalanır")
    func listWithTwoTriggerPhrasesStillCatchesBothItems() {
        let text = "Eser miktarda fındık, yer fıstığı içerebilir."
        let result = detector.detectWarningSentences(in: text)
        #expect(result.mayContain.contains(.nuts))
        #expect(result.mayContain.contains(.peanuts))
    }

    @Test("'Süt ve gluten içermez.' — tetikleyici (alerjen/içerir vb.) hiç yoksa hiçbir alerjen bulunmaz")
    func pureNegationWithNoTriggerWordFindsNothing() {
        let text = "Süt ve gluten içermez."
        let result = detector.detectWarningSentences(in: text)
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }
}
