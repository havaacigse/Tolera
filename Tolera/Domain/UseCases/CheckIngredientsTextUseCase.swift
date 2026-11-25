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

    init(checkProductUseCase: CheckProductUseCase = CheckProductUseCase()) {
        self.checkProductUseCase = checkProductUseCase
    }

    func execute(
        rawText: String,
        userAllergens: Set<Allergen>,
        customTerms: [String] = [],
        headingFound: Bool,
        barcode: String = "",
        brand: String? = nil,
        imageURL: URL? = nil,
        categories: [String] = []
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

        return MissingIngredientsHeadingRule.apply(to: result, headingFound: headingFound)
    }
}
