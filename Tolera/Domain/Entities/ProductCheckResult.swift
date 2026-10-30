import Foundation

enum CheckStatus {
    case unsafe
    case caution
    case safe
    case unknown
}

struct ProductCheckResult {
    let product: Product
    let status: CheckStatus
    let matchedAllergens: Set<Allergen>
    let matchedTraces: Set<Allergen>
    let detectedFromIngredients: Set<Allergen>
}
