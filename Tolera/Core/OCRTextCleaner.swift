import Foundation

/// Kamera/Vision ile okunan metindeki satır sonu ve tireyle bölünmüş kelime
/// sorunlarını düzeltir (ör. "buğ-\nday" → "buğday").
enum OCRTextCleaner {
    static func clean(_ text: String) -> String {
        var result = text.replacingOccurrences(
            of: #"-\s*\n\s*"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "\n", with: " ")
        result = result.replacingOccurrences(
            of: #"[ \t]+"#,
            with: " ",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
