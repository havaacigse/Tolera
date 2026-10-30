import Foundation
import NaturalLanguage

struct IngredientAllergenDetector {
    // "eggplant"/"nutmeg" "egg" kelimesiyle çakışmaz (bare "nut" eklenmediği için nutmeg zaten
    // güvenli), "coconut" ise "coconut milk" normalize edildikten sonra tamamen silinir.
    // "ekmek mayası" maya demektir, gluten içermez ("ekmek" bileşik yiyecek anahtar kelimesiyle
    // çakışmasın diye silinir); "kekik" baharattır, "kek" ile çakışmasın diye silinir.
    private let exceptions = [
        "hindistan cevizi", "kakao yağı", "maltodekstrin", "maltitol", "maltoz",
        "eggplant", "nutmeg", "coconut", "ekmek mayası", "kekik"
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
        .gluten: ["buğday", "arpa", "çavdar", "yulaf", "malt", "irmik", "irmiğ", "bulgur", "kepek", "kepeğ", "gluten", "galeta", "kuskus", "spelt", "wheat", "barley", "rye", "oat", "makarna", "şehriye", "erişte", "yufka", "ekmek", "bisküvi", "kraker", "simit", "kek", "kadayıf"],
        .milk: ["süt", "peynir", "tereyağ", "krema", "kaymak", "kaymağ", "yoğurt", "yoğurd", "laktoz", "kazein", "kazeinat", "peynir altı suyu", "whey", "milk"],
        .eggs: ["yumurta", "albümin", "egg", "mayonez"],
        .fish: ["balık", "balığ", "ançüez", "hamsi", "somon", "ton balığı", "fish"],
        .crustaceans: ["karides", "yengeç", "yengec", "ıstakoz", "kerevit", "shrimp", "crab"],
        .molluscs: ["midye", "kalamar", "ahtapot", "ahtapod", "istiridye", "mussel", "squid"],
        .peanuts: ["yer fıstığı", "yerfıstığı", "fıstık", "peanut"],
        .nuts: ["fındık", "fındığ", "badem", "ceviz", "kaju", "pikan", "makadamya", "hazelnut", "almond", "walnut", "cashew", "pistachio", "pecan", "macadamia", "sert kabuklu meyve", "sert kabuklu yemiş", "kabuklu yemiş"],
        .soybeans: ["soya", "soy"],
        .celery: ["kereviz", "celery"],
        .mustard: ["hardal", "mustard"],
        .sesame: ["susam", "tahin", "sesame"],
        .sulphites: ["sülfit", "sülfür dioksit", "metabisülfit", "e220", "e221", "e222", "e223", "e224", "e226", "e227", "e228", "sulphite", "sulfite"],
        .lupin: ["acı bakla", "lupin"]
    ]

    // "eser miktarda"/"may contain" bir BAŞLANGIÇ ifadesidir: önceki alerjenler contains,
    // sonrakiler mayContain sayılır.
    private let leadingTraceMarkers = ["eser miktar", "may contain"]

    // Başlangıç ifadesi yoksa ve sadece "içerebilir"/"bulunabilir" fiili varsa: parçadaki
    // her kelime ya bir alerjen anahtar kelimesinin parçası ya da aşağıdaki izinli
    // kelimelerden biri olmalı; dışında bir kelime varsa (belirsiz) hepsi contains, yoksa
    // hepsi mayContain. Bağlaç kelimeleri tam, kategori kelimeleri kelime başı eşleşir ki
    // "ürünleri", "meyveler", "türevleri", "tohumu" gibi çekimli halleri de karşılasın.
    private let trailingTriggerPhrases = ["içerebilir", "bulunabilir"]
    private let traceSentenceAllowedConnectorWords = ["ve", "ile", "veya", "bu", "iz", "may", "of", "and"]
    private let traceSentenceAllowedCategoryWords = [
        "ürün", "eser", "miktar", "içerebilir", "bulunabilir", "düzeyde",
        "contain", "traces", "meyve", "türev", "tohum"
    ]

    // "glutensiz yulaf/buğday": sadece "glutensiz"in hemen ardından gelen tahılı kapsar
    // (çapraz bulaşma riski, eser miktar); aynı cümledeki başka bir gluten kaynağı etkilenmez.
    private let glutenFreeCrossContaminationPhrases = ["glutensiz yulaf", "glutensiz buğday"]

    // "gluten içermez/içermiyor" sadece kendi ifadesini etkiler (silinir); metindeki
    // başka bir gluten kaynağı bu temizlikten sonra normal şekilde içerik sayılmaya devam eder.
    private let glutenNegationPhrases = ["gluten içermez", "gluten içermiyor"]

    private struct PartDetection {
        let contains: Set<Allergen>
        let mayContain: Set<Allergen>
    }

    func detect(in text: String) -> IngredientDetectionResult {
        let normalized = TurkishWordMatcher.normalize(text)

        guard isSupportedLanguage(normalized) else {
            return IngredientDetectionResult(contains: [], mayContain: [], isUnrecognizedLanguage: true)
        }

        let parts = normalized.components(separatedBy: CharacterSet(charactersIn: ".;\n"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var contains: Set<Allergen> = []
        var mayContain: Set<Allergen> = []

        for part in parts {
            let detection = detectAllergens(inPart: part)
            contains.formUnion(detection.contains)
            mayContain.formUnion(detection.mayContain)
        }

        // Aynı alerjen hem gerçek içerikte hem eser miktar uyarısında geçerse içerik önceliklidir.
        mayContain.subtract(contains)

        return IngredientDetectionResult(contains: contains, mayContain: mayContain, isUnrecognizedLanguage: false)
    }

    // NLLanguageRecognizer çok kısa metinlerde (tek kelime, "mayonez" gibi) güvenilir
    // değildir; bu uzunluğun altındaki metinler NLLanguageRecognizer yerine bilinen
    // kelime kontrolünden geçer (bkz. hasKnownWord).
    private let minimumLengthForLanguageDetection = 20

    // Latin dışı alfabeler: uzunluktan bağımsız olarak doğrudan "anlaşılamadı" sayılır.
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

    // Kısa metinlerde en az biri geçmeli: alerjen anahtar kelimeleri + yaygın içerikler.
    private let commonGenericIngredientWords = [
        "su", "şeker", "tuz", "yağ", "sirke", "maya", "nişasta", "aroma",
        "water", "sugar", "salt", "oil"
    ]

    /// Boş metin iyimser olarak desteklenmiş sayılır. Latin dışı alfabe içeren metin
    /// uzunluktan bağımsız desteklenmez. Kısa metinlerde en az bir bilinen kelime
    /// (alerjen anahtar kelimesi ya da yaygın içerik) aranır; yoksa desteklenmez.
    /// Yeterince uzun Latin alfabeli metinlerde NLLanguageRecognizer kullanılır.
    private func isSupportedLanguage(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        guard !containsNonLatinScript(trimmed) else { return false }

        guard trimmed.count >= minimumLengthForLanguageDetection else {
            return hasKnownWord(in: trimmed)
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let language = recognizer.dominantLanguage else { return true }

        return language == .turkish || language == .english
    }

    private func containsNonLatinScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            Self.nonLatinScriptRanges.contains { $0.contains(scalar.value) }
        }
    }

    private func hasKnownWord(in text: String) -> Bool {
        // "e220" gibi alfasayısal kodlar bölünmesin diye rakamlar da kelime karakteri sayılır.
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard !words.isEmpty else { return false }

        let knownWords = keywordsByAllergen.values.flatMap { $0 }
            + pistachioPhrases.flatMap { $0.components(separatedBy: " ") }
            + commonGenericIngredientWords

        return words.contains { word in
            knownWords.contains { TurkishWordMatcher.matchesWordStart(keyword: $0, in: word) }
        }
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

        var partContains: Set<Allergen> = []
        var partMayContain: Set<Allergen> = []

        if let markerRange = firstLeadingMarkerRange(in: normalized) {
            // "eser miktarda"/"may contain" bir başlangıç ifadesidir: öncesi contains, sonrası mayContain.
            let before = String(normalized[normalized.startIndex..<markerRange.lowerBound])
            let after = String(normalized[markerRange.upperBound...])
            partContains = detectKeywordAllergens(in: before)
            partMayContain = detectKeywordAllergens(in: after)
        } else {
            let allergens = detectKeywordAllergens(in: normalized)
            let hasTrailingTrigger = trailingTriggerPhrases.contains { TurkishWordMatcher.matchesWordStart(keyword: $0, in: normalized) }

            if !hasTrailingTrigger || allergens.isEmpty {
                partContains = allergens
            } else if hasUnaccountedWord(in: normalized) {
                // Alerjen ya da izinli kelime olmayan bir kelime var: hangisi eser miktar
                // belirsiz, temkinli taraf contains.
                partContains = allergens
            } else {
                // Parça sadece alerjenlerden ve izinli bağlaç kelimelerinden oluşuyor: hepsi eser miktar.
                partMayContain = allergens
            }
        }

        partMayContain.formUnion(forcedTrace)
        return PartDetection(contains: partContains, mayContain: partMayContain)
    }

    /// Parçadaki her kelimenin; eşleşen bir alerjen anahtar kelimesinin parçası mı, yoksa
    /// izinli bir bağlaç/kategori kelimesi mi olduğunu kontrol eder. Biri bile değilse
    /// metin belirsiz sayılır. Çok kelimeli anahtar kelimelerin ("sert kabuklu meyve" gibi)
    /// tek tek kelimeleri de bu sayede karşılanmış sayılır.
    private func hasUnaccountedWord(in text: String) -> Bool {
        // "e220" gibi alfasayısal kodlar bölünmesin diye rakamlar da kelime karakteri sayılır.
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let consumedWords = matchedAllergenKeywords(in: text).flatMap { $0.components(separatedBy: " ") }

        for word in words {
            let isConsumed = consumedWords.contains { TurkishWordMatcher.matchesWordStart(keyword: $0, in: word) }
            if isConsumed { continue }

            let isConnector = traceSentenceAllowedConnectorWords.contains { TurkishWordMatcher.matchesWholeWord(keyword: $0, in: word) }
            if isConnector { continue }

            let isCategoryWord = traceSentenceAllowedCategoryWords.contains { TurkishWordMatcher.matchesWordStart(keyword: $0, in: word) }
            if isCategoryWord { continue }

            return true
        }
        return false
    }

    /// Metinde eşleşen tüm alerjen anahtar kelimelerini (çok kelimeli olanlar dahil) döndürür.
    private func matchedAllergenKeywords(in text: String) -> [String] {
        var matched: [String] = []
        for phrase in pistachioPhrases where TurkishWordMatcher.matchesWordStart(keyword: phrase, in: text) {
            matched.append(phrase)
        }
        for keywords in keywordsByAllergen.values {
            for keyword in keywords where TurkishWordMatcher.matchesWordStart(keyword: keyword, in: text) {
                matched.append(keyword)
            }
        }
        return matched
    }

    private func firstLeadingMarkerRange(in text: String) -> Range<String.Index>? {
        var earliest: Range<String.Index>?
        for marker in leadingTraceMarkers {
            guard let range = text.range(of: marker) else { continue }
            if earliest == nil || range.lowerBound < earliest!.lowerBound {
                earliest = range
            }
        }
        return earliest
    }

    private func detectKeywordAllergens(in text: String) -> Set<Allergen> {
        var normalized = text
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

        return found
    }
}
