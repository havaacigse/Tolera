import Foundation
import SwiftData

/// `SavedIngredientsText`'in SwiftData karşılığı. Domain katmanı SwiftData'yı hiç
/// bilmez; domain ↔ model dönüşümü sadece bu dosyada yapılır (DTO'larla aynı desen).
@Model
final class SavedIngredientsTextModel {
    @Attribute(.unique) var barcode: String
    var productName: String?
    var brand: String?
    var imageURLString: String?
    var categories: [String]
    var ingredientsText: String
    var headingFound: Bool
    var savedAt: Date

    init(
        barcode: String,
        productName: String?,
        brand: String?,
        imageURLString: String?,
        categories: [String],
        ingredientsText: String,
        headingFound: Bool,
        savedAt: Date
    ) {
        self.barcode = barcode
        self.productName = productName
        self.brand = brand
        self.imageURLString = imageURLString
        self.categories = categories
        self.ingredientsText = ingredientsText
        self.headingFound = headingFound
        self.savedAt = savedAt
    }

    convenience init(from record: SavedIngredientsText) {
        self.init(
            barcode: record.barcode,
            productName: record.productName,
            brand: record.brand,
            imageURLString: record.imageURL?.absoluteString,
            categories: record.categories,
            ingredientsText: record.ingredientsText,
            headingFound: record.headingFound,
            savedAt: record.savedAt
        )
    }

    /// "Yeniden oku" ile üzerine yazma: aynı satır güncellenir, yeni satır eklenmez.
    func update(from record: SavedIngredientsText) {
        productName = record.productName
        brand = record.brand
        imageURLString = record.imageURL?.absoluteString
        categories = record.categories
        ingredientsText = record.ingredientsText
        headingFound = record.headingFound
        savedAt = record.savedAt
    }

    func toDomain() -> SavedIngredientsText {
        SavedIngredientsText(
            barcode: barcode,
            productName: productName,
            brand: brand,
            imageURL: imageURLString.flatMap(URL.init(string:)),
            categories: categories,
            ingredientsText: ingredientsText,
            headingFound: headingFound,
            savedAt: savedAt
        )
    }
}
