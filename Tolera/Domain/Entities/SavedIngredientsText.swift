import Foundation

/// Kullanıcının "Kontrol et" ile onayladığı bir OCR metninin barkoda bağlı hafızası.
/// Barkod başına tek kayıt vardır; aynı barkod için yeniden okutulduğunda ("Yeniden oku")
/// bu kayıt güncellenir, geçmişe ayrıca eklenmez (geçmiş için bkz. `ScanHistoryEntry`).
/// `brand`/`imageURL`/`categories` ürün OFF'ta bulunup sadece içindekiler metni eksikse
/// oradan taşınır; böylece OCR ile tamamlanan üründe de alternatif önerisi çalışabilir.
struct SavedIngredientsText: Identifiable {
    var id: String { barcode }

    let barcode: String
    let productName: String?
    let brand: String?
    let imageURL: URL?
    let categories: [String]
    let ingredientsText: String
    /// Ham, kesilmemiş OCR metni (varsa). `IngredientsSectionExtractor`'ın "içindekiler...
    /// besin değerleri" penceresinin dışında kalan alerjen uyarıları (ör. "Alerjen uyarısı:
    /// X içerebilir") bu metinde hâlâ mevcuttur; `ingredientsText` (ayıklanmış) bunları
    /// içermeyebilir. Hafızadan yeniden kontrol edilirken `detectWarningSentences` için
    /// kullanılır — yoksa ilk taramada yakalanan bir uyarı ikinci taramada (hafızadan)
    /// kaçırılabilir (güvenlik gerilemesi). Opsiyonel: eski kayıtlarda (bu alan eklenmeden
    /// önce) nil olur, SwiftData bunu sorunsuz lightweight migration ile açar.
    let rawText: String?
    /// `MissingIngredientsHeadingRule`'a geçirilir: metin kaydedilirken "içindekiler"
    /// başlığı bulunup bulunmadığı, yeniden hesaplamada da aynı kuralın uygulanması için saklanır.
    let headingFound: Bool
    let savedAt: Date

    init(
        barcode: String,
        productName: String?,
        brand: String?,
        imageURL: URL?,
        categories: [String],
        ingredientsText: String,
        rawText: String? = nil,
        headingFound: Bool,
        savedAt: Date
    ) {
        self.barcode = barcode
        self.productName = productName
        self.brand = brand
        self.imageURL = imageURL
        self.categories = categories
        self.ingredientsText = ingredientsText
        self.rawText = rawText
        self.headingFound = headingFound
        self.savedAt = savedAt
    }
}
