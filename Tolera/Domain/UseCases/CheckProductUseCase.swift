import Foundation

struct CheckProductUseCase {
    private let detector: IngredientAllergenDetector
    private let customTermDetector: CustomTermDetector

    init(
        detector: IngredientAllergenDetector = IngredientAllergenDetector(),
        customTermDetector: CustomTermDetector = CustomTermDetector()
    ) {
        self.detector = detector
        self.customTermDetector = customTermDetector
    }

    func execute(product: Product, userAllergens: Set<Allergen>, customTerms: [String] = []) -> ProductCheckResult {
        // Kozmetik ürünler için alerjen analizi şimdilik desteklenmiyor (INCI listeleri ayrı bir iş).
        guard product.type != .cosmetic else {
            return ProductCheckResult(
                product: product,
                status: .unknown,
                matchedAllergens: [],
                matchedTraces: [],
                detectedFromIngredients: [],
                matchedCustomTerms: [],
                isCosmeticNotSupported: true
            )
        }

        let detection = detector.detect(in: product.ingredientsText ?? "")
        let textMentionedAllergens = detection.contains.union(detection.mayContain)
        let detectedFromIngredients = textMentionedAllergens.subtracting(product.allergens)

        // Metinde (içerik ya da eser miktar olarak) hiç geçmeyen OFF etiketleri eklenir;
        // metinde eser miktar olarak geçen bir alerjen için metin önceliklidir.
        let offOnlyAllergens = product.allergens.subtracting(textMentionedAllergens)
        let allContains = detection.contains.union(offOnlyAllergens)
        let allTraces = product.traces.union(detection.mayContain)

        let matchedAllergens = allContains.intersection(userAllergens)
        let matchedTraces = allTraces.intersection(userAllergens)
            .subtracting(matchedAllergens)
        let matchedCustomTerms = customTermDetector.detect(customTerms: customTerms, in: product.ingredientsText ?? "")

        let noIngredientsText = product.ingredientsText?.isEmpty ?? true
        let unknownDueToMissingOfficialData = product.allergens.isEmpty && noIngredientsText
        let unknownDueToUncheckedCustomTerms = !customTerms.isEmpty && noIngredientsText

        let status: CheckStatus
        if !matchedAllergens.isEmpty || !matchedCustomTerms.isEmpty {
            status = .unsafe
        } else if !matchedTraces.isEmpty {
            status = .caution
        } else if unknownDueToMissingOfficialData || unknownDueToUncheckedCustomTerms {
            status = .unknown
        } else {
            status = .safe
        }

        return ProductCheckResult(
            product: product,
            status: status,
            matchedAllergens: matchedAllergens,
            matchedTraces: matchedTraces,
            detectedFromIngredients: detectedFromIngredients,
            matchedCustomTerms: matchedCustomTerms,
            isCosmeticNotSupported: false
        )
    }
}
