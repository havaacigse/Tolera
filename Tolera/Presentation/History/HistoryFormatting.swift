import Foundation

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
}
