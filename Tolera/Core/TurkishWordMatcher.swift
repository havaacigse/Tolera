import Foundation

/// Türkçe metinlerde kelime başı eşleşmesi için ortak yardımcı.
enum TurkishWordMatcher {
    static func normalize(_ text: String) -> String {
        text.lowercased(with: Locale(identifier: "tr_TR"))
    }

    static func matchesWordStart(keyword: String, in normalizedText: String) -> Bool {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: keyword)
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(normalizedText.startIndex..., in: normalizedText)
        return regex.firstMatch(in: normalizedText, range: range) != nil
    }
}
