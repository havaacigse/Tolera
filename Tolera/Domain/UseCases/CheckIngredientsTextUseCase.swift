import Foundation

/// OCR ile okunan (ve kullanıcı tarafından düzenlenebilen) ambalaj metnini analiz eder.
/// Barkod/kategori bilgisi olmadığı durumda sadece metne dayalı, minimal bir `Product`
/// üretir ve mevcut `CheckProductUseCase`'e devreder; bu yüzden aynı `ProductResultView`
/// değişmeden kullanılabilir. `barcode`/`brand`/`imageURL`/`categories` verilirse (barkod
/// hafızasından — `SavedIngredientsTextRepository` — servis edilen bir sonuç için) bunlar
/// `Product`'a taşınır; böylece hafızadan gelen sonuçlarda da alternatif önerisi (ileride)
/// çalışabilir. Varsayılanlar önceki davranışı korur, mevcut çağıran taraflar değişmez.
struct CheckIngredientsTextUseCase {
    private let checkProductUseCase: CheckProductUseCase
    private let detector: IngredientAllergenDetector

    init(
        checkProductUseCase: CheckProductUseCase = CheckProductUseCase(),
        detector: IngredientAllergenDetector = IngredientAllergenDetector()
    ) {
        self.checkProductUseCase = checkProductUseCase
        self.detector = detector
    }

    /// `fullRawText` verilirse (ham, kesilmemiş OCR metni), `IngredientsSectionExtractor`'ın
    /// içindekiler penceresinin DIŞINDA bıraktığı alerjen uyarı cümleleri de taranır (bkz.
    /// `IngredientAllergenDetector.detectWarningSentences`) — kullanıcı ekranda sadece
    /// ayıklanmış `rawText`i düzenlese bile bu tarama ham metin üzerinde çalışır. Bulunanlar
    /// `WarningSentenceAllergenMerger` ile temkinli ilkeyle (contains > mayContain) sonuca
    /// eklenir; sıralama önemli: önce birleştirme, SONRA başlık kuralı (böylece uyarıdan gelen
    /// bir eşleşme, "başlık bulunamadı" kuralının "safe → unknown" indirgemesini de doğru
    /// şekilde tetikler/önler).
    func execute(
        rawText: String,
        userAllergens: Set<Allergen>,
        customTerms: [String] = [],
        headingFound: Bool,
        barcode: String = "",
        brand: String? = nil,
        imageURL: URL? = nil,
        categories: [String] = [],
        fullRawText: String? = nil
    ) -> ProductCheckResult {
        let cleanedText = OCRTextCleaner.clean(rawText)
        let product = Product(
            barcode: barcode,
            name: "Taranan Ürün",
            brand: brand,
            imageURL: imageURL,
            ingredientsText: cleanedText,
            allergens: [],
            traces: [],
            categories: categories,
            type: .food
        )
        let result = checkProductUseCase.execute(
            product: product,
            userAllergens: userAllergens,
            customTerms: customTerms
        )

        let warningDetection = fullRawText.map(detector.detectWarningSentences)
        let mergedResult = WarningSentenceAllergenMerger.merge(
            result: result,
            warningDetection: warningDetection,
            userAllergens: userAllergens
        )

        return MissingIngredientsHeadingRule.apply(to: mergedResult, headingFound: headingFound)
    }
}
