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
    /// OCR akışına özgü: "içindekiler" başlığı metinde bulunamadı (bkz.
    /// `CheckIngredientsTextUseCase`). Bu durumda sonuç ASLA `safe` olamaz; temkinli
    /// ilke gereği `unknown`'a çevrilir. Barkod akışında her zaman false'tur.
    let isMissingIngredientsHeading: Bool
    /// Eşleşen her alerjen için "neden": metindeki tetikleyen ifade, ya da OFF etiketinden
    /// geldiyse "Open Food Facts etiketi". Sadece matchedAllergens/matchedTraces'teki alerjenleri kapsar.
    let allergenReasons: [Allergen: String]
}
