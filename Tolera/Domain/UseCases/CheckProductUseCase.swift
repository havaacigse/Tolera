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
        let detectedFromIngredients = detector.detect(in: product.ingredientsText ?? "")
            .subtracting(product.allergens)
        let allAllergens = product.allergens.union(detectedFromIngredients)

        let matchedAllergens = allAllergens.intersection(userAllergens)
        let matchedTraces = product.traces.intersection(userAllergens)
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
            matchedCustomTerms: matchedCustomTerms
        )
    }
}
