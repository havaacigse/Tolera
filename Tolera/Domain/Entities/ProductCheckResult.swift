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
    let matchedCustomTerms: [String]
    let isCosmeticNotSupported: Bool
    let isProfileEmpty: Bool
    /// Eşleşen her alerjen için "neden": metindeki tetikleyen ifade, ya da OFF etiketinden
    /// geldiyse "Open Food Facts etiketi". Sadece matchedAllergens/matchedTraces'teki alerjenleri kapsar.
    let allergenReasons: [Allergen: String]
}
