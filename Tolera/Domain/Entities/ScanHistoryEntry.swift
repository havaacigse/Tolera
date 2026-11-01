import Foundation

/// Bir tarama sonucunun hangi kaynaktan geldiği: Open Food/Beauty Facts etiketi mi,
/// yoksa kullanıcının çektiği ambalaj fotoğrafı mı. `RecheckScanHistoryEntryUseCase`
/// yeniden hesaplarken bu alana göre hangi use case'in (ve hangi kuralların) uygulanacağını seçer.
enum ScanSource {
    case off
    case ocrPhoto
}

/// Her taramada (barkod bulunsun/bulunmasın) oluşturulan, değişmez bir geçmiş kaydı.
/// Dokununca güncel profille yeniden hesaplanabilmesi için bir `Product` kurmaya yetecek
/// tüm alanları (ve OCR akışı için `headingFound`'u) taşır. `snapshotStatus` sadece liste
/// satırında (yeniden hesaplamadan önce) gösterilecek anlık görüntüdür.
struct ScanHistoryEntry: Identifiable {
    let id: UUID
    let barcode: String?
    let productName: String
    let brand: String?
    let imageURL: URL?
    let ingredientsText: String?
    let allergens: Set<Allergen>
    let traces: Set<Allergen>
    let categories: [String]
    let type: ProductType
    let headingFound: Bool
    let source: ScanSource
    let snapshotStatus: CheckStatus
    let scannedAt: Date

    init(
        id: UUID = UUID(),
        barcode: String?,
        productName: String,
        brand: String?,
        imageURL: URL?,
        ingredientsText: String?,
        allergens: Set<Allergen>,
        traces: Set<Allergen>,
        categories: [String],
        type: ProductType,
        headingFound: Bool,
        source: ScanSource,
        snapshotStatus: CheckStatus,
        scannedAt: Date = Date()
    ) {
        self.id = id
        self.barcode = barcode
        self.productName = productName
        self.brand = brand
        self.imageURL = imageURL
        self.ingredientsText = ingredientsText
        self.allergens = allergens
        self.traces = traces
        self.categories = categories
        self.type = type
        self.headingFound = headingFound
        self.source = source
        self.snapshotStatus = snapshotStatus
        self.scannedAt = scannedAt
    }
}
