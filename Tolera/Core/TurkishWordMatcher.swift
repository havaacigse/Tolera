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
        matches(keyword: keyword, in: normalizedText, requireTrailingBoundary: false)
    }

    /// `matchesWordStart`'ın aksine kelimenin TAMAMI eşleşmeli (ör. "su" kelimesi
    /// "süt" → "sut" içinde kelime başı olarak yanlışlıkla eşleşmesin diye).
    static func matchesWholeWord(keyword: String, in normalizedText: String) -> Bool {
        matches(keyword: keyword, in: normalizedText, requireTrailingBoundary: true)
    }

    private static func matches(keyword: String, in normalizedText: String, requireTrailingBoundary: Bool) -> Bool {
        let foldedKeyword = foldTurkishCharacters(keyword)
        let foldedText = foldTurkishCharacters(normalizedText)
        var pattern = "\\b" + NSRegularExpression.escapedPattern(for: foldedKeyword)
        if requireTrailingBoundary {
            pattern += "\\b"
        }
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(foldedText.startIndex..., in: foldedText)
        return regex.firstMatch(in: foldedText, range: range) != nil
    }
}
