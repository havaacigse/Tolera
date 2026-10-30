import Foundation

struct IngredientAllergenDetector {
    // "eggplant"/"nutmeg" "egg" kelimesiyle çakışmaz (bare "nut" eklenmediği için nutmeg zaten
    // güvenli), "coconut" ise "coconut milk" normalize edildikten sonra tamamen silinir.
    private let exceptions = [
        "hindistan cevizi", "kakao yağı", "maltodekstrin", "maltitol", "maltoz",
        "eggplant", "nutmeg", "coconut"
    ]

    // "Antep fıstığı/fıstıklı/fıstık" sert kabuklu yemiştir (Antep fıstığı/pistachio);
    // bare "fıstık" (peanuts) ile çakışmaması için generic aramadan önce ayıklanır.
    private let pistachioPhrases = ["antep fıstığı", "antep fıstıklı", "antep fıstık"]

    // Bitkisel sütler dairy değildir: "X sütü"/"X milk" kalıbında sadece süt kısmı silinir, X kalır.
    private let plantMilks: [(phrase: String, replacement: String)] = [
        ("badem sütü", "badem"),
        ("soya sütü", "soya"),
        ("yulaf sütü", "yulaf"),
        ("pirinç sütü", "pirinç"),
        ("hindistan cevizi sütü", "hindistan cevizi"),
        ("fındık sütü", "fındık"),
        ("coconut milk", "coconut")
    ]

    private let keywordsByAllergen: [Allergen: [String]] = [
        .gluten: ["buğday", "arpa", "çavdar", "yulaf", "malt", "irmik", "irmiğ", "bulgur", "kepek", "kepeğ", "gluten", "galeta", "kuskus", "spelt", "wheat", "barley", "rye", "oat"],
        .milk: ["süt", "peynir", "tereyağ", "krema", "kaymak", "kaymağ", "yoğurt", "yoğurd", "laktoz", "kazein", "kazeinat", "peynir altı suyu", "whey", "milk"],
        .eggs: ["yumurta", "albümin", "egg"],
        .fish: ["balık", "balığ", "ançüez", "hamsi", "somon", "ton balığı", "fish"],
        .crustaceans: ["karides", "yengeç", "yengec", "ıstakoz", "kerevit", "shrimp", "crab"],
        .molluscs: ["midye", "kalamar", "ahtapot", "ahtapod", "istiridye", "mussel", "squid"],
        .peanuts: ["yer fıstığı", "yerfıstığı", "fıstık", "peanut"],
        .nuts: ["fındık", "fındığ", "badem", "ceviz", "kaju", "pikan", "makadamya", "hazelnut", "almond", "walnut", "cashew", "pistachio", "pecan", "macadamia"],
        .soybeans: ["soya", "soy"],
        .celery: ["kereviz", "celery"],
        .mustard: ["hardal", "mustard"],
        .sesame: ["susam", "tahin", "sesame"],
        .sulphites: ["sülfit", "sülfür dioksit", "metabisülfit", "e220", "e221", "e222", "e223", "e224", "e226", "e227", "e228", "sulphite", "sulfite"],
        .lupin: ["acı bakla", "lupin"]
    ]

    // Bu ifadelerden birini içeren cümle parçası eser miktar (mayContain) sayılır.
    private let traceTriggerPhrases = ["içerebilir", "bulunabilir", "eser miktar", "may contain"]

    // "glutensiz yulaf/buğday": sadece "glutensiz"in hemen ardından gelen tahılı kapsar
    // (çapraz bulaşma riski, eser miktar); aynı cümledeki başka bir gluten kaynağı etkilenmez.
    private let glutenFreeCrossContaminationPhrases = ["glutensiz yulaf", "glutensiz buğday"]

    // "gluten içermez/içermiyor" sadece kendi ifadesini etkiler (silinir); metindeki
    // başka bir gluten kaynağı bu temizlikten sonra normal şekilde içerik sayılmaya devam eder.
    private let glutenNegationPhrases = ["gluten içermez", "gluten içermiyor"]

    private struct PartDetection {
        let normal: Set<Allergen>
        let forcedTrace: Set<Allergen>
    }

    func detect(in text: String) -> IngredientDetectionResult {
        let normalized = TurkishWordMatcher.normalize(text)
        let parts = normalized.components(separatedBy: CharacterSet(charactersIn: ".;\n"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var contains: Set<Allergen> = []
        var mayContain: Set<Allergen> = []

        for part in parts {
            let detection = detectAllergens(inPart: part)
            let isTrace = traceTriggerPhrases.contains { TurkishWordMatcher.matchesWordStart(keyword: $0, in: part) }
            if isTrace {
                mayContain.formUnion(detection.normal)
            } else {
                contains.formUnion(detection.normal)
            }
            mayContain.formUnion(detection.forcedTrace)
        }

        // Aynı alerjen hem gerçek içerikte hem eser miktar uyarısında geçerse içerik önceliklidir.
        mayContain.subtract(contains)

        return IngredientDetectionResult(contains: contains, mayContain: mayContain)
    }

    private func detectAllergens(inPart part: String) -> PartDetection {
        var normalized = part

        for plantMilk in plantMilks {
            normalized = normalized.replacingOccurrences(of: plantMilk.phrase, with: plantMilk.replacement)
        }

        for exception in exceptions {
            normalized = normalized.replacingOccurrences(of: exception, with: " ")
        }

        var forcedTrace: Set<Allergen> = []

        // Sadece "glutensiz"e bitişik tahılı ayıkla ve sil; metindeki başka bir gluten
        // kaynağı (ör. ayrı bir "buğday unu") bu adımdan etkilenmeden aşağıda yakalanır.
        for phrase in glutenFreeCrossContaminationPhrases where TurkishWordMatcher.matchesWordStart(keyword: phrase, in: normalized) {
            forcedTrace.insert(.gluten)
        }
        for phrase in glutenFreeCrossContaminationPhrases {
            normalized = normalized.replacingOccurrences(of: phrase, with: " ")
        }

        // "gluten içermez/içermiyor" ifadesinin kendisini sil; metindeki başka bir gluten
        // kaynağı bu temizlikten sonra aşağıda normal şekilde yakalanmaya devam eder.
        for phrase in glutenNegationPhrases {
            normalized = normalized.replacingOccurrences(of: phrase, with: " ")
        }

        var found: Set<Allergen> = []

        for phrase in pistachioPhrases where TurkishWordMatcher.matchesWordStart(keyword: phrase, in: normalized) {
            found.insert(.nuts)
        }
        for phrase in pistachioPhrases {
            normalized = normalized.replacingOccurrences(of: phrase, with: " ")
        }

        for (allergen, keywords) in keywordsByAllergen where keywords.contains(where: { TurkishWordMatcher.matchesWordStart(keyword: $0, in: normalized) }) {
            found.insert(allergen)
        }

        return PartDetection(normal: found, forcedTrace: forcedTrace)
    }
}
