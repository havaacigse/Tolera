import Foundation
import NaturalLanguage

/// İçindekiler metnini analiz edip alerjenleri "gerçek içerik" (contains) ve
/// "eser miktar" (mayContain) olarak ayıran kural tabanlı, deterministik dedektör.
/// Anahtar kelime/istisna/izinli kelime listeleri için bkz. `AllergenKeywords`.
struct IngredientAllergenDetector {
    private struct PartDetection {
        let contains: Set<Allergen>
        let mayContain: Set<Allergen>
    }

    /// Bir cümle parçasının başlangıç ifadesine göre ikiye bölünmüş hali
    /// (ör. "eser miktarda X" → öncesi/sonrası).
    private enum PartKind {
        case leadingMarker(before: String, after: String)
        case remainder(String)
    }

    // NLLanguageRecognizer çok kısa metinlerde (tek kelime, "mayonez" gibi) güvenilir
    // değildir; bu uzunluğun altındaki metinler NLLanguageRecognizer yerine bilinen
    // kelime kontrolünden geçer (bkz. `hasKnownWord`).
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

    // MARK: - Ana akış

    /// Sırasıyla: (1) normalize, (2) dil kontrolü, (3) parçalara bölme,
    /// (4-5) her parçayı sınıflandırıp anahtar kelimelerle eşleştirme,
    /// (6) sonuçları temkinli ilkeyle birleştirme.
    func detect(in text: String) -> IngredientDetectionResult {
        let normalizedText = normalize(text)

        guard isSupportedLanguage(normalizedText) else {
            return IngredientDetectionResult(contains: [], mayContain: [], isUnrecognizedLanguage: true)
        }

        let parts = splitIntoParts(normalizedText)
        let partDetections = parts.map(classifyAndMatch)

        return combine(partDetections)
    }

    // MARK: - 1. Normalize

    /// Metni Türkçe kurallarına göre küçük harfe çevirir (İ→i, I→ı doğru çalışsın).
    /// Böylece büyük/küçük harf farkı anahtar kelime eşleşmesini etkilemez.
    private func normalize(_ text: String) -> String {
        TurkishWordMatcher.normalize(text)
    }

    // MARK: - 2. Dil kontrolü

    /// Boş metin iyimser olarak desteklenmiş sayılır (ayrı bir use case kuralıyla ele alınır).
    /// Latin dışı alfabe (Kiril, Arapça vb.) içeren metin uzunluktan bağımsız desteklenmez,
    /// çünkü anahtar kelimelerimizin hiçbiri o alfabede yazılamaz. Kısa Latin-alfabeli
    /// metinlerde NLLanguageRecognizer güvenilir olmadığından (ör. "mayonez" tek kelime)
    /// en az bir bilinen kelime aranır; yeterince uzun metinde NLLanguageRecognizer kullanılır.
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

    /// Metinde Kiril/Arapça/İbranice/Yunanca/CJK/Hangul aralığında bir karakter var mı
    /// kontrol eder. Script düzeyinde kontrol, kısa metinlerde dahi çok güvenilirdir.
    private func containsNonLatinScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            Self.nonLatinScriptRanges.contains { $0.contains(scalar.value) }
        }
    }

    /// Kısa metin için: en az bir kelime bir alerjen anahtar kelimesi ya da yaygın bir
    /// içerik kelimesi (su, şeker, water, sugar vb.) olmalı; yoksa muhtemelen başka bir dil.
    private func hasKnownWord(in text: String) -> Bool {
        let words = tokenize(text)
        guard !words.isEmpty else { return false }

        let knownWords = AllergenKeywords.keywordsByAllergen.values.flatMap { $0 }
            + AllergenKeywords.pistachioPhrases.flatMap { $0.components(separatedBy: " ") }
            + AllergenKeywords.commonGenericIngredientWords

        return words.contains { word in
            knownWords.contains { TurkishWordMatcher.matchesWordStart(keyword: $0, in: word) }
        }
    }

    // MARK: - 3. Parçalara bölme

    /// Metni cümle/ifade parçalarına böler (. ; ve satır sonu). Her parça ayrı
    /// değerlendirilir ki bir cümledeki "eser miktar" ifadesi diğer cümleyi etkilemesin.
    private func splitIntoParts(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ".;\n"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - 4 ve 5. Parça sınıflandırma + anahtar kelime eşleşmesi

    /// Bir parçayı temizleyip (istisnalar, özel ifadeler) içerik/eser miktar olarak
    /// sınıflandırır ve o sınıflandırmaya göre anahtar kelime eşleşmesi yapar.
    private func classifyAndMatch(part: String) -> PartDetection {
        let (cleanedPart, forcedTrace) = applyExceptionsAndSpecialPhrases(to: part)
        let detection = classifyAndFindAllergens(in: cleanedPart)
        return PartDetection(contains: detection.contains, mayContain: detection.mayContain.union(forcedTrace))
    }

    /// İstisnaları ve özel ifadeleri temizler ki aşağıdaki anahtar kelime araması
    /// bunlardan yanlışlıkla etkilenmesin:
    /// - Bitkisel sütler ("badem sütü" → "badem"): süt alerjeni değildir.
    /// - İstisna kelimeler ("eggplant", "kekik" vb.): başka bir anahtar kelimenin öneki.
    /// - "glutensiz yulaf/buğday": çapraz bulaşma riski olduğu için ayrıca işaretlenip
    ///   (forcedTrace) metinden silinir ki aşağıda tekrar "içerik" olarak yakalanmasın.
    /// - "gluten içermez/içermiyor": sadece kendisi silinir, başka gluten kaynağı etkilenmez.
    private func applyExceptionsAndSpecialPhrases(to part: String) -> (cleaned: String, forcedTrace: Set<Allergen>) {
        var normalized = part

        for plantMilk in AllergenKeywords.plantMilks {
            normalized = normalized.replacingOccurrences(of: plantMilk.phrase, with: plantMilk.replacement)
        }

        for exception in AllergenKeywords.exceptions {
            normalized = normalized.replacingOccurrences(of: exception, with: " ")
        }

        var forcedTrace: Set<Allergen> = []
        for phrase in AllergenKeywords.glutenFreeCrossContaminationPhrases where TurkishWordMatcher.matchesWordStart(keyword: phrase, in: normalized) {
            forcedTrace.insert(.gluten)
        }
        for phrase in AllergenKeywords.glutenFreeCrossContaminationPhrases {
            normalized = normalized.replacingOccurrences(of: phrase, with: " ")
        }

        for phrase in AllergenKeywords.glutenNegationPhrases {
            normalized = normalized.replacingOccurrences(of: phrase, with: " ")
        }

        return (normalized, forcedTrace)
    }

    /// Temizlenmiş parçayı sınıflandırır: başlangıç ifadesi varsa öncesi/sonrasına göre,
    /// yoksa fiil (içerebilir/bulunabilir) ve belirsizlik durumuna göre contains/mayContain
    /// olarak ayırıp anahtar kelimeleri bulur. Temkinli ilke: belirsizlikte hep contains.
    private func classifyAndFindAllergens(in part: String) -> PartDetection {
        switch classifyPartKind(part) {
        case let .leadingMarker(before, after):
            // "eser miktarda"/"may contain" bir BAŞLANGIÇ ifadesidir: öncesi contains, sonrası mayContain.
            return PartDetection(contains: findAllergens(in: before), mayContain: findAllergens(in: after))

        case let .remainder(text):
            let allergens = findAllergens(in: text)
            let hasTrailingTrigger = AllergenKeywords.trailingTriggerPhrases.contains {
                TurkishWordMatcher.matchesWordStart(keyword: $0, in: text)
            }

            guard hasTrailingTrigger, !allergens.isEmpty else {
                // Fiil yok ya da hiç alerjen bulunamadı: varsayılan olarak içerik sayılır.
                return PartDetection(contains: allergens, mayContain: [])
            }

            if hasUnaccountedWord(in: text) {
                // Alerjen ya da izinli kelime olmayan bir kelime var: hangisi eser miktar
                // belirsiz, temkinli ilke gereği hepsi içerik sayılır.
                return PartDetection(contains: allergens, mayContain: [])
            }

            // Parça sadece alerjenlerden ve izinli bağlaç/kategori kelimelerinden oluşuyor: hepsi eser miktar.
            return PartDetection(contains: [], mayContain: allergens)
        }
    }

    /// Parçada "eser miktarda"/"may contain" başlangıç ifadesi var mı bakar; varsa onun
    /// konumundan ikiye böler, yoksa parçanın tamamını döndürür.
    private func classifyPartKind(_ part: String) -> PartKind {
        guard let markerRange = firstLeadingMarkerRange(in: part) else {
            return .remainder(part)
        }
        let before = String(part[part.startIndex..<markerRange.lowerBound])
        let after = String(part[markerRange.upperBound...])
        return .leadingMarker(before: before, after: after)
    }

    /// Metindeki en erken başlayan "eser miktarda"/"may contain" ifadesinin konumunu bulur.
    private func firstLeadingMarkerRange(in text: String) -> Range<String.Index>? {
        var earliest: Range<String.Index>?
        for marker in AllergenKeywords.leadingTraceMarkers {
            guard let range = text.range(of: marker) else { continue }
            if earliest == nil || range.lowerBound < earliest!.lowerBound {
                earliest = range
            }
        }
        return earliest
    }

    /// Parçadaki her kelimenin; eşleşen bir alerjen anahtar kelimesinin parçası mı, yoksa
    /// izinli bir bağlaç/kategori kelimesi mi olduğunu kontrol eder. Biri bile değilse
    /// metin belirsiz sayılır. Çok kelimeli anahtar kelimelerin ("sert kabuklu meyve" gibi)
    /// tek tek kelimeleri de bu sayede karşılanmış sayılır.
    private func hasUnaccountedWord(in text: String) -> Bool {
        let words = tokenize(text)
        let consumedWords = matchedAllergenKeywords(in: text).flatMap { $0.components(separatedBy: " ") }

        for word in words {
            let isConsumed = consumedWords.contains { TurkishWordMatcher.matchesWordStart(keyword: $0, in: word) }
            if isConsumed { continue }

            let isConnector = AllergenKeywords.traceSentenceAllowedConnectorWords.contains {
                TurkishWordMatcher.matchesWholeWord(keyword: $0, in: word)
            }
            if isConnector { continue }

            let isCategoryWord = AllergenKeywords.traceSentenceAllowedCategoryWords.contains {
                TurkishWordMatcher.matchesWordStart(keyword: $0, in: word)
            }
            if isCategoryWord { continue }

            return true
        }
        return false
    }

    /// Metinde eşleşen tüm alerjen anahtar kelimelerini (çok kelimeli olanlar dahil) döndürür.
    private func matchedAllergenKeywords(in text: String) -> [String] {
        var matched: [String] = []
        for phrase in AllergenKeywords.pistachioPhrases where TurkishWordMatcher.matchesWordStart(keyword: phrase, in: text) {
            matched.append(phrase)
        }
        for keywords in AllergenKeywords.keywordsByAllergen.values {
            for keyword in keywords where TurkishWordMatcher.matchesWordStart(keyword: keyword, in: text) {
                matched.append(keyword)
            }
        }
        return matched
    }

    /// Ham anahtar kelime araması: önce Antep fıstığı özel durumu (nuts, bare "fıstık"
    /// ile çakışmasın diye önce ayıklanıp silinir), sonra sözlükteki tüm anahtar kelimeler.
    private func findAllergens(in text: String) -> Set<Allergen> {
        var normalized = text
        var found: Set<Allergen> = []

        for phrase in AllergenKeywords.pistachioPhrases where TurkishWordMatcher.matchesWordStart(keyword: phrase, in: normalized) {
            found.insert(.nuts)
        }
        for phrase in AllergenKeywords.pistachioPhrases {
            normalized = normalized.replacingOccurrences(of: phrase, with: " ")
        }

        for (allergen, keywords) in AllergenKeywords.keywordsByAllergen where keywords.contains(where: { TurkishWordMatcher.matchesWordStart(keyword: $0, in: normalized) }) {
            found.insert(allergen)
        }

        return found
    }

    /// Metni kelimelere ayırır. Rakamlar da kelime karakteri sayılır ki "e220" gibi
    /// alfasayısal kodlar "e" ve "220"ye bölünüp kaybolmasın.
    private func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    // MARK: - 6. Birleştirme (temkinli ilke)

    /// Tüm parçaların sonuçlarını birleştirir. Aynı alerjen hem içerikte hem eser
    /// miktarda geçerse içerik kazanır (CLAUDE.md: contains > mayContain > yok).
    private func combine(_ detections: [PartDetection]) -> IngredientDetectionResult {
        var contains: Set<Allergen> = []
        var mayContain: Set<Allergen> = []

        for detection in detections {
            contains.formUnion(detection.contains)
            mayContain.formUnion(detection.mayContain)
        }

        mayContain.subtract(contains)

        return IngredientDetectionResult(contains: contains, mayContain: mayContain, isUnrecognizedLanguage: false)
    }
}
