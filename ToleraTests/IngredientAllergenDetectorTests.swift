import Testing
@testable import Tolera

struct IngredientAllergenDetectorTests {
    private let detector = IngredientAllergenDetector()

    @Test("buğday unu glüten olarak yakalanır")
    func wheatFlourDetectsGluten() {
        let result = detector.detect(in: "buğday unu, şeker")
        #expect(result.contains == [.gluten])
        #expect(result.mayContain.isEmpty)
    }

    @Test("büyük harfli ve Türkçe İ içeren süt ifadeleri yakalanır")
    func uppercaseTurkishTextDetectsMilk() {
        let result = detector.detect(in: "SÜT TOZU, İNEK SÜTÜ")
        #expect(result.contains == [.milk])
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"sütlü\" kelimesi süt alerjeni olarak yakalanır")
    func sutluWordDetectsMilk() {
        let result = detector.detect(in: "sütlü çikolata")
        #expect(result.contains == [.milk])
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"fındığı\" çekimli hali sert kabuklu yemiş olarak yakalanır")
    func findigiInflectedFormDetectsNuts() {
        let result = detector.detect(in: "fındığı ezilmiş")
        #expect(result.contains == [.nuts])
        #expect(result.mayContain.isEmpty)
    }

    @Test("kaymak ve süt birlikte geçtiğinde süt alerjeni döner")
    func kaymakAndMilkDetectMilk() {
        let result = detector.detect(in: "kaymağı alınmış süt")
        #expect(result.contains == [.milk])
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"ton balığı\" ifadesi balık alerjeni olarak yakalanır")
    func tunaFishDetectsFish() {
        let result = detector.detect(in: "ton balığı, zeytinyağı")
        #expect(result.contains == [.fish])
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"hindistan cevizi\" istisnadır, alerjen sayılmaz")
    func coconutIsException() {
        let result = detector.detect(in: "hindistan cevizi")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"hindistan cevizi sütü\" süt alerjeni sayılmaz")
    func coconutMilkIsNotDairy() {
        let result = detector.detect(in: "hindistan cevizi sütü")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"badem sütü\" süt değil, sert kabuklu yemiş olarak yakalanır")
    func almondMilkDetectsNutsNotMilk() {
        let result = detector.detect(in: "badem sütü")
        #expect(result.contains == [.nuts])
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"maltodekstrin\" gluten alerjeni olarak yanlış yakalanmaz")
    func maltodextrinDoesNotTriggerGluten() {
        let result = detector.detect(in: "maltodekstrin, şeker")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"arpa maltı\" gluten alerjeni olarak yakalanır")
    func barleyMaltDetectsGluten() {
        let result = detector.detect(in: "arpa maltı")
        #expect(result.contains == [.gluten])
        #expect(result.mayContain.isEmpty)
    }

    @Test("E220 kodu sülfit alerjeni olarak yakalanır")
    func e220CodeDetectsSulphites() {
        let result = detector.detect(in: "koruyucu (E220)")
        #expect(result.contains == [.sulphites])
        #expect(result.mayContain.isEmpty)
    }

    @Test("alerjen içermeyen bir metinde hiçbir alerjen bulunmaz")
    func plainTextHasNoAllergens() {
        let result = detector.detect(in: "su, şeker, tuz")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    @Test("birden fazla alerjen aynı metinde birlikte yakalanır")
    func multipleAllergensDetectedTogether() {
        let result = detector.detect(in: "yumurta, susam, soya lesitini")
        #expect(result.contains == [.eggs, .sesame, .soybeans])
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"antep fıstığı\" sert kabuklu yemiştir, yer fıstığı sayılmaz")
    func antepPistachioDetectsNutsNotPeanuts() {
        let result = detector.detect(in: "antep fıstığı içerir")
        #expect(result.contains == [.nuts])
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"antep fıstıklı baklava\" sert kabuklu yemiştir, yer fıstığı sayılmaz")
    func antepPistachioAdjectiveFormDetectsNutsNotPeanuts() {
        let result = detector.detect(in: "antep fıstıklı baklava")
        #expect(result.contains == [.nuts])
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"fıstıklı\" (antep öneki olmadan) yer fıstığı olarak yakalanır")
    func bareFistikliDetectsPeanuts() {
        let result = detector.detect(in: "fıstıklı çikolata")
        #expect(result.contains == [.peanuts])
        #expect(result.mayContain.isEmpty)
    }

    // MARK: - Eser miktar (trace) cümle ayrımı

    @Test("tamamı eser miktar uyarısı olan tarçın metninde gerçek içerik boş, eser miktar dolu olmalı")
    func traceOnlyCinnamonTextHasEmptyContentAndFullTrace() {
        let text = "Öğütülmüş Tarçın. Eser miktarda gluten, yumurta, soya, susam, süt ürünleri, kereviz, badem, fıstık içerebilir."
        let result = detector.detect(in: text)
        #expect(result.contains.isEmpty)
        #expect(result.mayContain == [.gluten, .eggs, .soybeans, .sesame, .milk, .celery, .nuts, .peanuts])
    }

    @Test("\"fındık içerebilir\" eser miktardır, gluten gerçek içeriktir")
    func traceHazelnutDoesNotLeakIntoContent() {
        let text = "buğday unu, şeker. Fındık içerebilir."
        let result = detector.detect(in: text)
        #expect(result.contains == [.gluten])
        #expect(result.mayContain == [.nuts])
    }

    @Test("\"yer fıstığı bulunabilir\" eser miktardır, süt gerçek içeriktir")
    func tracePeanutDoesNotLeakIntoContent() {
        let text = "süt, kakao. Eser miktarda yer fıstığı bulunabilir."
        let result = detector.detect(in: text)
        #expect(result.contains == [.milk])
        #expect(result.mayContain == [.peanuts])
    }

    @Test("İngilizce \"may contain traces of milk\" ifadesi eser miktar sayılır")
    func englishMayContainPhraseDetectsMilkAsTrace() {
        let result = detector.detect(in: "May contain traces of milk.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain == [.milk])
    }

    // MARK: - İngilizce anahtar kelimeler

    @Test("İngilizce tahıl kelimeleri gluten olarak yakalanır")
    func englishGrainKeywordsDetectGluten() {
        let result = detector.detect(in: "Contains wheat, barley, rye and oat.")
        #expect(result.contains == [.gluten])
        #expect(result.mayContain.isEmpty)
    }

    @Test("İngilizce sert kabuklu yemiş kelimeleri doğru alerjeni yakalar")
    func englishNutKeywordsDetectNuts() {
        let result = detector.detect(in: "Contains hazelnut, walnut, cashew, pistachio, pecan and macadamia.")
        #expect(result.contains == [.nuts])
        #expect(result.mayContain.isEmpty)
    }

    @Test("İngilizce deniz ürünü kelimeleri kabuklu/yumuşakça olarak ayrılır")
    func englishSeafoodKeywordsDetectCrustaceansAndMolluscs() {
        let result = detector.detect(in: "Contains shrimp, crab, mussel and squid.")
        #expect(result.contains == [.crustaceans, .molluscs])
        #expect(result.mayContain.isEmpty)
    }

    @Test("İngilizce diğer alerjen kelimeleri doğru yakalanır")
    func englishMiscKeywordsDetectCorrectAllergens() {
        let result = detector.detect(in: "Contains soy, celery, mustard, sesame, sulphite and lupin.")
        #expect(result.contains == [.soybeans, .celery, .mustard, .sesame, .sulphites, .lupin])
        #expect(result.mayContain.isEmpty)
    }

    @Test("Amerikan yazımı \"sulfite\" de sülfit olarak yakalanır")
    func americanSulfiteSpellingDetectsSulphites() {
        let result = detector.detect(in: "Contains sulfite.")
        #expect(result.contains == [.sulphites])
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"eggplant\" ve \"nutmeg\" alerjen olarak yakalanmaz")
    func eggplantAndNutmegAreNotAllergens() {
        let result = detector.detect(in: "Eggplant and nutmeg are not allergens.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    @Test("İngilizce \"coconut milk\" süt alerjeni sayılmaz")
    func coconutMilkIsNotDairyInEnglish() {
        let result = detector.detect(in: "Coconut milk.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    // MARK: - "Glutensiz" beyanı ve Türkçe karakter toleransı

    @Test("\"glutensiz yulaf unu\" kalıbında gluten eser miktar olmalı, içerik değil")
    func glutenFreeOatFlourMarksGlutenAsTraceNotContent() {
        let result = detector.detect(in: "glutensiz yulaf unu")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain == [.gluten])
    }

    @Test("\"gluten içermez\" ifadesinde hiçbir alerjen yakalanmamalı")
    func glutenContainsNegationDetectsNothing() {
        let result = detector.detect(in: "gluten içermez")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    @Test("Türkçe karakter toleransı: \"findik, sut tozu\" sert kabuklu yemiş ve süt olarak yakalanmalı")
    func asciiFoldedTurkishCharactersStillMatchNutsAndMilk() {
        let result = detector.detect(in: "findik, sut tozu")
        #expect(result.contains == [.nuts, .milk])
        #expect(result.mayContain.isEmpty)
    }

    @Test("Türkçe karakter toleransı: \"bugday unu\" gluten olarak yakalanmalı")
    func asciiFoldedBugdayStillMatchesGluten() {
        let result = detector.detect(in: "bugday unu")
        #expect(result.contains == [.gluten])
        #expect(result.mayContain.isEmpty)
    }

    @Test("Türkçe karakter toleransı alakasız kelimelerde yanlış pozitif oluşturmaz")
    func asciiFoldedToleranceDoesNotIntroduceFalsePositives() {
        let result = detector.detect(in: "su, seker, tuz, nisasta")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    // MARK: - "glutensiz" ve "gluten içermez" kapsamı

    @Test("\"glutensiz\" kuralı sadece hemen ardından gelen tahıla uygulanır, diğer gluten kaynakları içerik kalır")
    func glutenFreeRuleOnlyAppliesToImmediatelyFollowingGrain() {
        let result = detector.detect(in: "buğday unu, şeker, glutensiz yulaf")
        #expect(result.contains == [.gluten])
    }

    @Test("\"gluten içermez\" sadece kendisini etkiler, metindeki başka gluten kaynağı içerik kalır")
    func glutenNegationOnlyAffectsItselfNotOtherSources() {
        let result = detector.detect(in: "buğday unu, şeker. gluten içermez.")
        #expect(result.contains == [.gluten])
    }

    @Test("Aynı cümlede olsalar bile \"gluten içermez\" diğer gluten kaynağını etkilemez")
    func glutenNegationInSameSentenceStillKeepsOtherSource() {
        let result = detector.detect(in: "buğday unu içerir, gluten içermez")
        #expect(result.contains == [.gluten])
    }

    @Test("Gerçek gluten kaynağı yoksa \"gluten içermez\" hiçbir şey yakalamaz")
    func glutenNegationWithNoRealSourceDetectsNothing() {
        let result = detector.detect(in: "pirinç, mısır. gluten içermez.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    // MARK: - Noktasız eser miktar cümleleri

    @Test("Alerjen olmayan içerik (şeker) varsa belirsizdir, hepsi contains sayılır")
    func ambiguousTraceSentenceWithFillerIngredientIsAllContains() {
        let result = detector.detect(in: "şeker, buğday unu, fındık içerebilir")
        #expect(result.contains == [.gluten, .nuts])
        #expect(result.mayContain.isEmpty)
    }

    @Test("\"eser miktarda\" başlangıç ifadesinden önceki contains, sonraki mayContain")
    func leadingTraceMarkerSplitsBeforeAndAfter() {
        let result = detector.detect(in: "şeker, buğday unu. eser miktarda fındık içerebilir")
        #expect(result.contains == [.gluten])
        #expect(result.mayContain == [.nuts])
    }

    @Test("Beyaz listede olmayan bir kelime (kakao) varsa belirsizdir, hepsi contains sayılır")
    func unknownWordOutsideWhitelistMakesSentenceAmbiguous() {
        let result = detector.detect(in: "kakao, fındık içerebilir")
        #expect(result.contains == [.nuts])
        #expect(result.mayContain.isEmpty)
    }

    @Test("Sadece alerjenler ve izinli bağlaç kelimeleri varsa hepsi mayContain sayılır")
    func onlyAllergensAndAllowedConnectorWordsIsAllMayContain() {
        let result = detector.detect(in: "Bu ürün fındık, süt ve soya içerebilir.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain == [.nuts, .milk, .soybeans])
    }

    @Test("Parça sadece alerjenlerden oluşuyorsa hepsi mayContain sayılır")
    func partConsistingOnlyOfAllergensIsAllMayContain() {
        let result = detector.detect(in: "fındık ve süt içerebilir.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain == [.nuts, .milk])
    }

    // MARK: - Sık görülen etiket ifadeleri

    @Test("\"Süt ürünleri içerebilir.\" → mayContain [milk]")
    func dairyProductsPhraseDetectsMilkAsTrace() {
        let result = detector.detect(in: "Süt ürünleri içerebilir.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain == [.milk])
    }

    @Test("\"Yer fıstığı içerebilir.\" → mayContain [peanuts]")
    func peanutPhraseDetectsPeanutsAsTrace() {
        let result = detector.detect(in: "Yer fıstığı içerebilir.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain == [.peanuts])
    }

    @Test("\"Sert kabuklu meyve içerebilir.\" → mayContain [nuts]")
    func hardShelledFruitPhraseDetectsNutsAsTrace() {
        let result = detector.detect(in: "Sert kabuklu meyve içerebilir.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain == [.nuts])
    }

    @Test("\"Sert kabuklu meyveler ve susam içerebilir.\" → mayContain [nuts, sesame]")
    func hardShelledFruitsAndSesamePhraseDetectsBothAsTrace() {
        let result = detector.detect(in: "Sert kabuklu meyveler ve susam içerebilir.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain == [.nuts, .sesame])
    }

    @Test("\"Kabuklu yemişler içerebilir.\" → mayContain [nuts]")
    func shelledNutsPhraseDetectsNutsAsTrace() {
        let result = detector.detect(in: "Kabuklu yemişler içerebilir.")
        #expect(result.contains.isEmpty)
        #expect(result.mayContain == [.nuts])
    }

    @Test("\"Sert kabuklu meyveler\" içerik listesinde geçerse contains [nuts] olur")
    func hardShelledFruitsInContentListIsContains() {
        let result = detector.detect(in: "Sert kabuklu meyveler, şeker, tuz.")
        #expect(result.contains == [.nuts])
        #expect(result.mayContain.isEmpty)
    }

    // MARK: - Bileşik yiyecekler

    @Test("Un bazlı bileşik yiyecekler gluten olarak yakalanır (makarna, şehriye, erişte, yufka)")
    func pastaAndDoughCompoundFoodsDetectGluten() {
        let result = detector.detect(in: "makarna, şehriye, erişte, yufka")
        #expect(result.contains == [.gluten])
    }

    @Test("Fırın ürünleri gluten olarak yakalanır (ekmek, bisküvi, kraker, simit, kek, kadayıf)")
    func bakeryCompoundFoodsDetectGluten() {
        let result = detector.detect(in: "ekmek, bisküvi, kraker, simit, kek, kadayıf")
        #expect(result.contains == [.gluten])
    }

    @Test("\"mayonez\" yumurta alerjeni olarak yakalanır")
    func mayonnaiseDetectsEggs() {
        let result = detector.detect(in: "mayonez")
        #expect(result.contains == [.eggs])
    }

    @Test("\"ekmek mayası\" (maya) gluten olarak yanlış yakalanmaz")
    func breadYeastDoesNotFalselyTriggerGluten() {
        let result = detector.detect(in: "ekmek mayası, su, tuz")
        #expect(result.contains.isEmpty)
    }

    @Test("\"kekik\" (baharat) \"kek\" kelimesinden gluten olarak yanlış yakalanmaz")
    func thymeDoesNotFalselyTriggerGlutenFromKek() {
        let result = detector.detect(in: "kekik, tuz, zeytinyağı")
        #expect(result.contains.isEmpty)
    }

    // MARK: - Yabancı dil tespiti

    @Test("Arapça metin anlaşılamadı olarak işaretlenir")
    func arabicTextIsMarkedAsUnrecognizedLanguage() {
        let result = detector.detect(in: "يحتوي هذا المنتج على القمح والحليب والبيض")
        #expect(result.isUnrecognizedLanguage)
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    @Test("Rusça metin anlaşılamadı olarak işaretlenir")
    func russianTextIsMarkedAsUnrecognizedLanguage() {
        let result = detector.detect(in: "Этот продукт содержит пшеницу, молоко и яйца")
        #expect(result.isUnrecognizedLanguage)
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    @Test("Kiril alfabesiyle kısa metin de (uzunluktan bağımsız) anlaşılamadı sayılır")
    func cyrillicShortTextIsUnrecognizedRegardlessOfLength() {
        let result = detector.detect(in: "Мука, сахар")
        #expect(result.isUnrecognizedLanguage)
    }

    @Test("Latin alfabeli ama bilinen kelime içermeyen kısa yabancı metin anlaşılamadı sayılır")
    func shortLatinTextWithNoKnownWordIsUnrecognized() {
        let result = detector.detect(in: "Weizenmehl, Zucker")
        #expect(result.isUnrecognizedLanguage)
    }

    @Test("\"mayonez\" kısa olsa da bilinen bir alerjen kelimesi, anlaşılamadı sayılmaz")
    func shortTextWithKnownAllergenWordIsNotUnrecognized() {
        let result = detector.detect(in: "mayonez")
        #expect(!result.isUnrecognizedLanguage)
        #expect(result.contains == [.eggs])
    }

    @Test("\"su\" kısa olsa da bilinen yaygın bir kelime, anlaşılamadı sayılmaz")
    func shortTextWithKnownGenericWordIsNotUnrecognized() {
        let result = detector.detect(in: "su")
        #expect(!result.isUnrecognizedLanguage)
        #expect(result.contains.isEmpty)
        #expect(result.mayContain.isEmpty)
    }

    // MARK: - Dil kontrolü sadece "safe"i engeller, alerjen bulunduğunda devreye girmez

    /// Gerçek cihaz hatası: marka adı ağırlıklı, 20+ karakterlik bir OCR metninde
    /// NLLanguageRecognizer metni Türkçe/İngilizce olarak tanımayabiliyor ("BİRŞAH"
    /// gibi marka kelimesi yüzünden), ama metinde "yoğurt" (süt) geçiyor. Alerjen
    /// araması dil kontrolünden ÖNCE yapılmalı ki bu durumda yanlışlıkla "unknown"
    /// dönülmesin.
    @Test("Marka adı ağırlıklı kısa OCR metninde \"yoğurt\" geçerse dil kontrolü sonucu ezmez")
    func brandHeavyOcrTextWithMilkKeywordIsNotUnrecognized() {
        let result = detector.detect(in: "BİRŞAH YOĞURT TAM YAĞLI 500 G")
        #expect(!result.isUnrecognizedLanguage)
        #expect(result.contains == [.milk])
    }

    @Test("Türkçe karakter eksik \"yogurt\" da aynı şekilde dil kontrolünden önce bulunur")
    func brandHeavyOcrTextWithAsciiMilkKeywordIsNotUnrecognized() {
        let result = detector.detect(in: "BIRSAH YOGURT 500G")
        #expect(!result.isUnrecognizedLanguage)
        #expect(result.contains == [.milk])
    }

    @Test("Hiç alerjen kelimesi eşleşmeyen Kiril metin anlaşılamadı kalır")
    func cyrillicTextWithNoAllergenMatchStillUnrecognized() {
        let result = detector.detect(in: "Мука, сахар, молоко")
        #expect(result.isUnrecognizedLanguage)
        #expect(result.contains.isEmpty)
    }

    // MARK: - "Neden?" (tetikleyen ifade)

    @Test("gluten alerjeni için tetikleyen ifade (virgülle ayrılmış öğe) döner")
    func glutenReasonReturnsTriggeringCommaItem() {
        let result = detector.detect(in: "buğday unu, şeker")
        #expect(result.reasons[.gluten] == "buğday unu")
    }

    @Test("eser miktar alerjeni için tetikleyen ifade döner")
    func traceAllergenReasonReturnsTriggeringPhrase() {
        let result = detector.detect(in: "eser miktarda fındık içerebilir")
        #expect(result.reasons[.nuts] == "fındık içerebilir")
    }

    @Test("\"glutensiz yulaf\" çapraz bulaşma uyarısının tetikleyen ifadesi kendisidir")
    func glutenFreeCrossContaminationReasonIsThePhraseItself() {
        let result = detector.detect(in: "glutensiz yulaf unu")
        #expect(result.reasons[.gluten] == "glutensiz yulaf")
    }
}
