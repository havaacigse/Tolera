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

        return MissingIngredientsHeadingRule.apply(to: result, headingFound: headingFound)
    }
}
