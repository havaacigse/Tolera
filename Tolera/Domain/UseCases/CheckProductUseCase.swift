import Foundation

struct CheckProductUseCase {
    private let detector: IngredientAllergenDetector
    private let customTermDetector: CustomTermDetector

    init(
        detector: IngredientAllergenDetector = IngredientAllergenDetector(),
        customTermDetector: CustomTermDetector = CustomTermDetector()
    ) {
        self.detector = detector
        self.customTermDetector = customTermDetector
    }

    func execute(product: Product, userAllergens: Set<Allergen>, customTerms: [String] = []) -> ProductCheckResult {
        // Kozmetik ürünler için alerjen analizi şimdilik desteklenmiyor (INCI listeleri ayrı bir iş).
        guard product.type != .cosmetic else {
            return ProductCheckResult(
                product: product,
                status: .unknown,
                matchedAllergens: [],
                matchedTraces: [],
                detectedFromIngredients: [],
                matchedCustomTerms: [],
                isCosmeticNotSupported: true,
                isProfileEmpty: false,
                isMissingIngredientsHeading: false,
                allergenReasons: [:]
            )
        }

        // Kullanıcı hiçbir alerjen/özel terim seçmemişse analiz anlamsızdır; "safe"
        // dönmek yanıltıcı olur, bu yüzden ayrı bir bayrakla işaretlenir.
        guard !(userAllergens.isEmpty && customTerms.isEmpty) else {
            return ProductCheckResult(
                product: product,
                status: .unknown,
                matchedAllergens: [],
                matchedTraces: [],
                detectedFromIngredients: [],
                matchedCustomTerms: [],
                isCosmeticNotSupported: false,
                isProfileEmpty: true,
                isMissingIngredientsHeading: false,
                allergenReasons: [:]
            )
        }

        let detection = detector.detect(in: product.ingredientsText ?? "")

        // İçindekiler metni Türkçe/İngilizce dışında bir dildeyse analiz güvenilmez;
        // metin hiç anlaşılamadığı için durum unknown olur.
        guard !detection.isUnrecognizedLanguage else {
            return ProductCheckResult(
                product: product,
                status: .unknown,
                matchedAllergens: [],
                matchedTraces: [],
                detectedFromIngredients: [],
                matchedCustomTerms: [],
                isCosmeticNotSupported: false,
                isProfileEmpty: false,
                isMissingIngredientsHeading: false,
                allergenReasons: [:]
            )
        }

        let textMentionedAllergens = detection.contains.union(detection.mayContain)
        let detectedFromIngredients = textMentionedAllergens.subtracting(product.allergens)

        // Metinde (içerik ya da eser miktar olarak) hiç geçmeyen OFF etiketleri eklenir;
        // metinde eser miktar olarak geçen bir alerjen için metin önceliklidir.
        let offOnlyAllergens = product.allergens.subtracting(textMentionedAllergens)
        let allContains = detection.contains.union(offOnlyAllergens)
        let allTraces = product.traces.union(detection.mayContain)

        let matchedAllergens = allContains.intersection(userAllergens)
        let matchedTraces = allTraces.intersection(userAllergens)
            .subtracting(matchedAllergens)
        let matchedCustomTerms = customTermDetector.detect(customTerms: customTerms, in: product.ingredientsText ?? "")

        let noIngredientsText = product.ingredientsText?.isEmpty ?? true
        let unknownDueToMissingOfficialData = product.allergens.isEmpty && noIngredientsText
        let unknownDueToUncheckedCustomTerms = !customTerms.isEmpty && noIngredientsText

        let status: CheckStatus
        if !matchedAllergens.isEmpty || !matchedCustomTerms.isEmpty {
            status = .unsafe
        } else if !matchedTraces.isEmpty {
            status = .caution
        } else if unknownDueToMissingOfficialData || unknownDueToUncheckedCustomTerms {
            status = .unknown
        } else {
            status = .safe
        }

        // "Neden bu sonuç?" için: metinden gelen tetikleyen ifade varsa onu kullan,
        // yoksa bu alerjen OFF etiketinden gelmiş demektir.
        var allergenReasons: [Allergen: String] = [:]
        for allergen in matchedAllergens.union(matchedTraces) {
            allergenReasons[allergen] = detection.reasons[allergen] ?? "Open Food Facts etiketi"
        }

        return ProductCheckResult(
            product: product,
            status: status,
            matchedAllergens: matchedAllergens,
            matchedTraces: matchedTraces,
            detectedFromIngredients: detectedFromIngredients,
            matchedCustomTerms: matchedCustomTerms,
            isCosmeticNotSupported: false,
            isProfileEmpty: false,
            isMissingIngredientsHeading: false,
            allergenReasons: allergenReasons
        )
    }
}
