import Foundation

/// Türkçe metinlerde kelime başı eşleşmesi için ortak yardımcı.
enum TurkishWordMatcher {
    private static let asciiFoldMap: [Character: Character] = [
        "ı": "i", "ğ": "g", "ş": "s", "ç": "c", "ö": "o", "ü": "u"
    ]

    static func normalize(_ text: String) -> String {
        text.lowercased(with: Locale(identifier: "tr_TR"))
    }

    /// Türkçe karakter eksik/yanlış yazılmış metinlerde de eşleşsin diye
    /// ı/i, ğ/g, ş/s, ç/c, ö/o, ü/u'yu ortak bir forma indirger.
    private static func foldTurkishCharacters(_ text: String) -> String {
        String(text.map { asciiFoldMap[$0] ?? $0 })
    }

    static func matchesWordStart(keyword: String, in normalizedText: String) -> Bool {
        let foldedKeyword = foldTurkishCharacters(keyword)
        let foldedText = foldTurkishCharacters(normalizedText)
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: foldedKeyword)
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(foldedText.startIndex..., in: foldedText)
        return regex.firstMatch(in: foldedText, range: range) != nil
    }
}
