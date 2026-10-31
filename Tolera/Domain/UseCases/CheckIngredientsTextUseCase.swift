import Foundation

/// OCR ile okunan (ve kullanıcı tarafından düzenlenebilen) ambalaj metnini analiz eder.
/// Barkod/kategori bilgisi olmadığı için sadece metne dayalı, minimal bir `Product`
/// üretir ve mevcut `CheckProductUseCase`'e devreder; bu yüzden aynı `ProductResultView`
/// değişmeden kullanılabilir. Kategori olmadığından alternatif önerisi bu akışta
/// hiç tetiklenmez (`FindAlternativesUseCase` boş kategoride arama yapmaz).
struct CheckIngredientsTextUseCase {
    private let checkProductUseCase: CheckProductUseCase

    init(checkProductUseCase: CheckProductUseCase = CheckProductUseCase()) {
        self.checkProductUseCase = checkProductUseCase
    }

    func execute(
        rawText: String,
        userAllergens: Set<Allergen>,
        customTerms: [String] = [],
        headingFound: Bool
    ) -> ProductCheckResult {
        let cleanedText = OCRTextCleaner.clean(rawText)
        let product = Product(
            barcode: "",
            name: "Taranan Ürün",
            brand: nil,
            imageURL: nil,
            ingredientsText: cleanedText,
            allergens: [],
            traces: [],
            categories: [],
            type: .food
        )
        let result = checkProductUseCase.execute(
            product: product,
            userAllergens: userAllergens,
            customTerms: customTerms
        )

        // Temkinli ilke: "içindekiler" başlığı metinde hiç bulunamadıysa (ör. OCR sadece
        // üretim yeri/adres kısmını okumuş olabilir), analiz edilen metnin güvenilirliği
        // belirsizdir. Bu durumda sonuç ASLA "safe" olamaz — gerçekten alerjen eşleştiyse
        // (unsafe/caution) bu geçerliliğini korur, ama "hiçbir şey bulunamadı" sonucu
        // yanlışlıkla "güvenli" yerine "yetersiz bilgi" olarak işaretlenir.
        guard !headingFound, result.status == .safe else { return result }

        return ProductCheckResult(
            product: result.product,
            status: .unknown,
            matchedAllergens: result.matchedAllergens,
            matchedTraces: result.matchedTraces,
            detectedFromIngredients: result.detectedFromIngredients,
            matchedCustomTerms: result.matchedCustomTerms,
            isCosmeticNotSupported: result.isCosmeticNotSupported,
            isProfileEmpty: result.isProfileEmpty,
            isMissingIngredientsHeading: true,
            allergenReasons: result.allergenReasons
        )
    }
}
