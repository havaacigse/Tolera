import Foundation

struct IngredientAllergenDetector {
    private let exceptions = ["hindistan cevizi", "kakao yağı", "maltodekstrin", "maltitol", "maltoz"]

    // "Antep fıstığı/fıstıklı/fıstık" sert kabuklu yemiştir (Antep fıstığı/pistachio);
    // bare "fıstık" (peanuts) ile çakışmaması için generic aramadan önce ayıklanır.
    private let pistachioPhrases = ["antep fıstığı", "antep fıstıklı", "antep fıstık"]

    // Bitkisel sütler dairy değildir: "X sütü" kalıbında sadece "sütü" kısmı silinir, X kalır.
    private let plantMilks: [(phrase: String, replacement: String)] = [
        ("badem sütü", "badem"),
        ("soya sütü", "soya"),
        ("yulaf sütü", "yulaf"),
        ("pirinç sütü", "pirinç"),
        ("hindistan cevizi sütü", "hindistan cevizi"),
        ("fındık sütü", "fındık")
    ]

    private let keywordsByAllergen: [Allergen: [String]] = [
        .gluten: ["buğday", "arpa", "çavdar", "yulaf", "malt", "irmik", "irmiğ", "bulgur", "kepek", "kepeğ", "gluten", "galeta", "kuskus", "spelt"],
        .milk: ["süt", "peynir", "tereyağ", "krema", "kaymak", "kaymağ", "yoğurt", "yoğurd", "laktoz", "kazein", "kazeinat", "peynir altı suyu", "whey"],
        .eggs: ["yumurta", "albümin"],
        .fish: ["balık", "balığ", "ançüez", "hamsi", "somon", "ton balığı"],
        .crustaceans: ["karides", "yengeç", "yengec", "ıstakoz", "kerevit"],
        .molluscs: ["midye", "kalamar", "ahtapot", "ahtapod", "istiridye"],
        .peanuts: ["yer fıstığı", "yerfıstığı", "fıstık"],
        .nuts: ["fındık", "fındığ", "badem", "ceviz", "kaju", "pikan", "makadamya"],
        .soybeans: ["soya"],
        .celery: ["kereviz"],
        .mustard: ["hardal"],
        .sesame: ["susam", "tahin"],
        .sulphites: ["sülfit", "sülfür dioksit", "metabisülfit", "e220", "e221", "e222", "e223", "e224", "e226", "e227", "e228"],
        .lupin: ["acı bakla", "lupin"]
    ]

    func detect(in text: String) -> Set<Allergen> {
        var normalized = text.lowercased(with: Locale(identifier: "tr_TR"))

        for plantMilk in plantMilks {
            normalized = normalized.replacingOccurrences(of: plantMilk.phrase, with: plantMilk.replacement)
        }

        for exception in exceptions {
            normalized = normalized.replacingOccurrences(of: exception, with: " ")
        }

        var found: Set<Allergen> = []

        for phrase in pistachioPhrases where matchesWordStart(keyword: phrase, in: normalized) {
            found.insert(.nuts)
        }
        for phrase in pistachioPhrases {
            normalized = normalized.replacingOccurrences(of: phrase, with: " ")
        }

        for (allergen, keywords) in keywordsByAllergen where keywords.contains(where: { matchesWordStart(keyword: $0, in: normalized) }) {
            found.insert(allergen)
        }
        return found
    }

    private func matchesWordStart(keyword: String, in text: String) -> Bool {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: keyword)
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
