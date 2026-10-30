import Foundation

enum ProductType: Hashable {
    case food
    case cosmetic
}

struct Product: Identifiable, Hashable {
    var id: String { barcode }

    let barcode: String
    let name: String
    let brand: String?
    let imageURL: URL?
    let ingredientsText: String?
    let allergens: Set<Allergen>
    let traces: Set<Allergen>
    let categories: [String]
    let type: ProductType
}
