import Foundation

struct OFFProductResponseDTO: Decodable {
    let status: Int
    let product: OFFProductDTO?
}

struct OFFProductDTO: Decodable {
    let code: String?
    let productName: String?
    let productNameTr: String?
    let brands: String?
    let imageFrontUrl: String?
    let ingredientsText: String?
    let ingredientsTextTr: String?
    let allergensTags: [String]?
    let tracesTags: [String]?
    let categoriesTags: [String]?
    let productType: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameTr = "product_name_tr"
        case brands
        case imageFrontUrl = "image_front_url"
        case ingredientsText = "ingredients_text"
        case ingredientsTextTr = "ingredients_text_tr"
        case allergensTags = "allergens_tags"
        case tracesTags = "traces_tags"
        case categoriesTags = "categories_tags"
        case productType = "product_type"
    }

    /// Türkçe alan varsa onu, yoksa genel alanı döndürür.
    private func preferred(_ tr: String?, _ general: String?) -> String? {
        if let tr, !tr.isEmpty { return tr }
        if let general, !general.isEmpty { return general }
        return nil
    }

    func toDomain() -> Product? {
        guard let barcode = code, let name = preferred(productNameTr, productName) else {
            return nil
        }

        let ingredients = preferred(ingredientsTextTr, ingredientsText)
            .map(IngredientsTextCleaner.clean)

        let allergens = Set((allergensTags ?? []).compactMap(Allergen.from(offTag:)))
        let traces = Set((tracesTags ?? []).compactMap(Allergen.from(offTag:)))

        return Product(
            barcode: barcode,
            name: name,
            brand: brands,
            imageURL: imageFrontUrl.flatMap(URL.init(string:)),
            ingredientsText: ingredients,
            allergens: allergens,
            traces: traces,
            categories: categoriesTags ?? [],
            type: productType == "beauty" ? .cosmetic : .food
        )
    }
}
