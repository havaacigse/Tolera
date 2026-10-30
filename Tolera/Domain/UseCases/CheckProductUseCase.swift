import Foundation

struct CheckProductUseCase {
    private let detector: IngredientAllergenDetector

    init(detector: IngredientAllergenDetector = IngredientAllergenDetector()) {
        self.detector = detector
    }

    func execute(product: Product, userAllergens: Set<Allergen>) -> ProductCheckResult {
        let detectedFromIngredients = detector.detect(in: product.ingredientsText ?? "")
            .subtracting(product.allergens)
        let allAllergens = product.allergens.union(detectedFromIngredients)

        let matchedAllergens = allAllergens.intersection(userAllergens)
        let matchedTraces = product.traces.intersection(userAllergens)
            .subtracting(matchedAllergens)

        let status: CheckStatus
        if !matchedAllergens.isEmpty {
            status = .unsafe
        } else if !matchedTraces.isEmpty {
            status = .caution
        } else if product.allergens.isEmpty && (product.ingredientsText?.isEmpty ?? true) {
            status = .unknown
        } else {
            status = .safe
        }

        return ProductCheckResult(
            product: product,
            status: status,
            matchedAllergens: matchedAllergens,
            matchedTraces: matchedTraces,
            detectedFromIngredients: detectedFromIngredients
        )
    }
}
