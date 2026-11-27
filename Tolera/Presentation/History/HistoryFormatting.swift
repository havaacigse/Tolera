import Foundation

/// `HistoryDetailView`'da bir alerjen/iz satırı: alerjen adı + o alerjenin eşleşme gerekçesi
/// (`ProductCheckResult.allergenReasons`'tan aynen alınır, burada YENİ bir metin üretilmez).
struct HistoryAllergenReason: Identifiable, Equatable {
    var id: Allergen { allergen }
    let allergen: Allergen
    let reason: String
}

/// `HistoryView`'ın kullandığı metin biçimlendirmeleri. View'dan ayrı, saf (side-effect'siz)
/// fonksiyonlar olarak tutulur ki View'a dokunmadan test edilebilsinler.
enum HistoryFormatting {
    static func dayHeaderText(for day: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) {
            return "Bugün"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "Dün"
        }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    static func statusLabelText(for status: CheckStatus) -> String {
        switch status {
        case .unsafe: return "Uygun değil"
        case .caution: return "Dikkat"
        case .safe: return "Uygun"
        case .unknown: return "Bilinmiyor"
        }
    }

    static func sourceText(for source: ScanSource) -> String {
        switch source {
        case .off: return "Barkod"
        case .ocrPhoto: return "Fotoğraf"
        }
    }

    /// Ürün adı → barkod → "Adsız ürün", bu sırayla.
    static func displayName(for entry: ScanHistoryEntry) -> String {
        if !entry.productName.isEmpty { return entry.productName }
        if let barcode = entry.barcode, !barcode.isEmpty { return barcode }
        return "Adsız ürün"
    }

    /// `result.matchedAllergens`'taki her alerjen için `result.allergenReasons`'tan
    /// gerekçesini aynen taşır — YENİ bir hesaplama/gerekçe üretmez. Sıralama alerjenin
    /// Türkçe görünen adına göredir (kararlı, test edilebilir sıra için).
    static func matchedAllergenReasons(for result: ProductCheckResult) -> [HistoryAllergenReason] {
        result.matchedAllergens
            .sorted { $0.displayName < $1.displayName }
            .map { HistoryAllergenReason(allergen: $0, reason: result.allergenReasons[$0] ?? "") }
    }

    /// Aynı mantık, `result.matchedTraces` (eser miktar/iz) için.
    static func matchedTraceReasons(for result: ProductCheckResult) -> [HistoryAllergenReason] {
        result.matchedTraces
            .sorted { $0.displayName < $1.displayName }
            .map { HistoryAllergenReason(allergen: $0, reason: result.allergenReasons[$0] ?? "") }
    }

    /// Durum `.unknown` olduğunda nedenini `ProductCheckResult`'ın mevcut alanlarından
    /// çıkarır — yeni bir hesaplama yapmaz, sadece zaten hesaplanmış sonuçtaki bayrakları
    /// okur. Öncelik sırası `CheckProductUseCase`'teki guard sırasıyla aynıdır (bu bayraklar
    /// birbirini dışlar: aynı anda en fazla biri true olabilir, bkz. o dosyadaki erken
    /// `return`'ler). Hiçbiri set değilse ve içindekiler metni de doluysa, kalan tek
    /// ihtimal `CheckProductUseCase`'in "dil tanınmadı" erken dönüşüdür — bu durumda
    /// `ProductCheckResult`'ta bunu ayıran özel bir bayrak YOK, bu yüzden kesin değil,
    /// en olası açıklama olarak belirtilir.
    static func unknownReasonText(for result: ProductCheckResult) -> String? {
        guard result.status == .unknown else { return nil }

        if result.isCosmeticNotSupported {
            return "Kozmetik ürünler için alerjen analizi şu an desteklenmiyor."
        }
        if result.isProfileEmpty {
            return "Profilinde hiç alerjen veya özel terim seçili değil."
        }
        if result.isMissingIngredientsHeading {
            return "İçindekiler başlığı metinde bulunamadı, bu yüzden sonuç güvenilir sayılmadı."
        }
        let noIngredientsText = result.product.ingredientsText?.isEmpty ?? true
        if noIngredientsText {
            return "Bu ürün için içindekiler bilgisi yok."
        }
        return "İçindekiler metni anlaşılamadı (desteklenmeyen bir dilde olabilir)."
    }
}
