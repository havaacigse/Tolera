import Foundation
import SwiftData

/// `ScanHistoryEntry`'nin SwiftData karşılığı. `Allergen` zaten `String` rawValue'lu
/// olduğundan diziye çevrilip saklanır; `ProductType`/`ScanSource`/`CheckStatus` için
/// basit string kodlama/kod açma yardımcıları aşağıda tanımlı (domain enum'ları
/// SwiftData'yı bilmemeli).
@Model
final class ScanHistoryEntryModel {
    @Attribute(.unique) var id: UUID
    var barcode: String?
    var productName: String
    var brand: String?
    var imageURLString: String?
    var ingredientsText: String?
    var allergensRaw: [String]
    var tracesRaw: [String]
    var categories: [String]
    var typeRaw: String
    var headingFound: Bool
    var sourceRaw: String
    var snapshotStatusRaw: String
    var scannedAt: Date

    init(
        id: UUID,
        barcode: String?,
        productName: String,
        brand: String?,
        imageURLString: String?,
        ingredientsText: String?,
        allergensRaw: [String],
        tracesRaw: [String],
        categories: [String],
        typeRaw: String,
        headingFound: Bool,
        sourceRaw: String,
        snapshotStatusRaw: String,
        scannedAt: Date
    ) {
        self.id = id
        self.barcode = barcode
        self.productName = productName
        self.brand = brand
        self.imageURLString = imageURLString
        self.ingredientsText = ingredientsText
        self.allergensRaw = allergensRaw
        self.tracesRaw = tracesRaw
        self.categories = categories
        self.typeRaw = typeRaw
        self.headingFound = headingFound
        self.sourceRaw = sourceRaw
        self.snapshotStatusRaw = snapshotStatusRaw
        self.scannedAt = scannedAt
    }

    convenience init(from entry: ScanHistoryEntry) {
        self.init(
            id: entry.id,
            barcode: entry.barcode,
            productName: entry.productName,
            brand: entry.brand,
            imageURLString: entry.imageURL?.absoluteString,
            ingredientsText: entry.ingredientsText,
            allergensRaw: entry.allergens.map(\.rawValue),
            tracesRaw: entry.traces.map(\.rawValue),
            categories: entry.categories,
            typeRaw: Self.encode(entry.type),
            headingFound: entry.headingFound,
            sourceRaw: Self.encode(entry.source),
            snapshotStatusRaw: Self.encode(entry.snapshotStatus),
            scannedAt: entry.scannedAt
        )
    }

    func toDomain() -> ScanHistoryEntry {
        ScanHistoryEntry(
            id: id,
            barcode: barcode,
            productName: productName,
            brand: brand,
            imageURL: imageURLString.flatMap(URL.init(string:)),
            ingredientsText: ingredientsText,
            allergens: Set(allergensRaw.compactMap(Allergen.init(rawValue:))),
            traces: Set(tracesRaw.compactMap(Allergen.init(rawValue:))),
            categories: categories,
            type: Self.decodeType(typeRaw),
            headingFound: headingFound,
            source: Self.decodeSource(sourceRaw),
            snapshotStatus: Self.decodeStatus(snapshotStatusRaw),
            scannedAt: scannedAt
        )
    }

    private static func encode(_ type: ProductType) -> String {
        switch type {
        case .food: return "food"
        case .cosmetic: return "cosmetic"
        }
    }

    private static func decodeType(_ raw: String) -> ProductType {
        raw == "cosmetic" ? .cosmetic : .food
    }

    private static func encode(_ source: ScanSource) -> String {
        switch source {
        case .off: return "off"
        case .ocrPhoto: return "ocrPhoto"
        }
    }

    private static func decodeSource(_ raw: String) -> ScanSource {
        raw == "ocrPhoto" ? .ocrPhoto : .off
    }

    private static func encode(_ status: CheckStatus) -> String {
        switch status {
        case .unsafe: return "unsafe"
        case .caution: return "caution"
        case .safe: return "safe"
        case .unknown: return "unknown"
        }
    }

    private static func decodeStatus(_ raw: String) -> CheckStatus {
        switch raw {
        case "unsafe": return .unsafe
        case "caution": return .caution
        case "safe": return .safe
        default: return .unknown
        }
    }
}
