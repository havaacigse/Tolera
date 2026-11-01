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
    /// `MissingIngredientsHeadingRule`'a geçirilir: metin kaydedilirken "içindekiler"
    /// başlığı bulunup bulunmadığı, yeniden hesaplamada da aynı kuralın uygulanması için saklanır.
    let headingFound: Bool
    let savedAt: Date
}
