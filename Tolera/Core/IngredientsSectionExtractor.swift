import Foundation

/// OCR ile okunan ambalaj metninden "içindekiler" bölümünü ayıklar: başlık öncesi
/// (marka/logo gibi gürültü) ve "besin değerleri" gibi sonraki bölümler elenir.
/// Başlık bulunamazsa metnin tamamı döner.
enum IngredientsSectionExtractor {
    private static let startMarkerPatterns = ["icindekiler", "bilesenler", "ingredients"]
    private static let endMarkerPatterns = ["besin\\s+degerleri", "beslenme\\s+bilgisi", "enerji", "nutrition"]

    private static let trimCharacterSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-"))

    static func extract(from text: String) -> String {
        let normalizedText = fold(text)
        let characters = Array(text)

        var startOffset = 0
        if let range = firstMatchCharacterRange(for: startMarkerPatterns, in: normalizedText) {
            startOffset = min(range.upperBound, characters.count)
        }

        var endOffset = characters.count
        if let range = firstMatchCharacterRange(for: endMarkerPatterns, in: normalizedText, searchingFrom: startOffset) {
            endOffset = max(range.lowerBound, startOffset)
        }

        guard startOffset < endOffset else {
            return text.trimmingCharacters(in: trimCharacterSet)
        }

        return String(characters[startOffset..<endOffset]).trimmingCharacters(in: trimCharacterSet)
    }

    /// Metinde "içindekiler"/"bileşenler"/"ingredients" başlığı var mı? `extract` başlık
    /// bulunamazsa metnin tamamını döndürdüğü için (gürültü metni de dahil), bu bilgi ayrıca
    /// saklanmalı: başlıksız bir metin (ör. sadece üretim yeri/adres) yanlışlıkla "safe"
    /// sayılmasın diye çağıran taraf (bkz. `CheckIngredientsTextUseCase`) bunu kullanır.
    static func headingFound(in text: String) -> Bool {
        firstMatchCharacterRange(for: startMarkerPatterns, in: fold(text)) != nil
    }

    private static let asciiFoldMap: [Character: Character] = [
        "ı": "i", "İ": "i", "I": "i",
        "ğ": "g", "Ğ": "g",
        "ş": "s", "Ş": "s",
        "ç": "c", "Ç": "c",
        "ö": "o", "Ö": "o",
        "ü": "u", "Ü": "u"
    ]

    /// Türkçe karakter eksik/hatalı OCR çıktılarında da başlık eşleşsin diye
    /// ı/İ/I → i, ğ/ş/ç/ö/ü varyantlarını ortak forma indirger ve küçük harfe çevirir.
    private static func fold(_ text: String) -> String {
        String(text.map { asciiFoldMap[$0] ?? Character(String($0).lowercased()) })
    }

    private static func firstMatchCharacterRange(
        for patterns: [String],
        in normalizedText: String,
        searchingFrom startOffset: Int = 0
    ) -> Range<Int>? {
        guard let searchStartIndex = normalizedText.index(
            normalizedText.startIndex, offsetBy: startOffset, limitedBy: normalizedText.endIndex
        ) else { return nil }

        let searchRange = NSRange(searchStartIndex..., in: normalizedText)
        var best: Range<Int>?

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: "\\b" + pattern + "\\b") else { continue }
            guard let match = regex.firstMatch(in: normalizedText, range: searchRange) else { continue }
            guard let swiftRange = Range(match.range, in: normalizedText) else { continue }

            let lower = normalizedText.distance(from: normalizedText.startIndex, to: swiftRange.lowerBound)
            let upper = normalizedText.distance(from: normalizedText.startIndex, to: swiftRange.upperBound)

            if best == nil || lower < best!.lowerBound {
                best = lower..<upper
            }
        }
        return best
    }
}
