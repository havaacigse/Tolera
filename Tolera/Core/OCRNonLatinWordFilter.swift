import Foundation

/// OCR ile okunan çok dilli ambalaj metinlerinde (ör. Arapça/Rusça bölümler) sadece
/// Latin alfabesi dışında karakter içeren KELİMELERİ atar; aynı satırdaki Türkçe/İngilizce
/// kısım olduğu gibi kalır (ör. "Buğday unu / دقيق القمح, şeker" → "Buğday unu / şeker").
/// Satır sonları korunur ki `OCRTextCleaner`'ın tire+satır sonu birleştirmesi bozulmasın.
///
/// Not: Bu sadece OCR akışında (metin düzenleme ekranına gelmeden önce) kullanılır. OFF'tan
/// gelen metinlerdeki temkinli davranış (Latin dışı alfabe → unknown, bkz.
/// `IngredientAllergenDetector.containsNonLatinScript`) buradan etkilenmez ve değişmez.
enum OCRNonLatinWordFilter {
    private static let nonLatinScriptRanges: [ClosedRange<UInt32>] = [
        0x0370...0x03FF,   // Yunan
        0x0400...0x04FF,   // Kiril
        0x0500...0x052F,   // Kiril eki
        0x0590...0x05FF,   // İbranice
        0x0600...0x06FF,   // Arapça
        0x0750...0x077F,   // Arapça eki
        0x3040...0x309F,   // Hiragana
        0x30A0...0x30FF,   // Katakana
        0x4E00...0x9FFF,   // CJK (Çince/Japonca/Korece ideogramları)
        0xAC00...0xD7A3    // Hangul
    ]

    static func removeNonLatinWords(from text: String) -> String {
        text.components(separatedBy: "\n")
            .map(filterLine)
            .joined(separator: "\n")
    }

    private static func filterLine(_ line: String) -> String {
        line.components(separatedBy: .whitespaces)
            .filter { !containsNonLatinScript($0) }
            .joined(separator: " ")
    }

    private static func containsNonLatinScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            nonLatinScriptRanges.contains { $0.contains(scalar.value) }
        }
    }
}
