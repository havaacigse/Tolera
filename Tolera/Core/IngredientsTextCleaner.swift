import Foundation

/// OFF'tan gelen içindekiler metnindeki vurgu/işaretleme karakterlerini temizler
/// (ör. `_buğday_`, `*süt*`, `[şeker, ...]`, `&quot;`). DTO ve değerlendirme
/// testleri aynı temizliği kullanır ki dedektöre giden metin birebir aynı olsun.
enum IngredientsTextCleaner {
    static func clean(_ text: String) -> String {
        var result = text
        for marker in ["_", "*", "[", "]", "&quot;"] {
            result = result.replacingOccurrences(of: marker, with: "")
        }
        return result
    }
}
