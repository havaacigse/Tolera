import Foundation

/// `IngredientAllergenDetector.detectWarningSentences`'ten gelen tespitleri bir
/// `ProductCheckResult`e temkinli ilkeyle (contains > mayContain > none) ekler.
///
/// Uyarılar SAHTE bir OFF etiketi gibi `Product.allergens`/`traces`'e enjekte EDİLMEZ:
/// `CheckProductUseCase`, bir alerjen içindekiler metninde (içerik ya da eser miktar olarak)
/// ZATEN geçiyorsa OFF etiketini "tekrar" saymaz (`offOnlyAllergens` çıkarması) — bu, gerçek
/// OFF etiketleri için doğru bir kural ("içindekiler metni OFF etiketine üstün gelir") ama
/// uyarı cümlesi bağlamında YANLIŞ: bir uyarı "X içerir" diyorsa, içindekiler metnindeki daha
/// zayıf bir "eser miktar" ifadesi bunu EZMEMELİ. Bu yüzden birleştirme burada, EŞLEŞMİŞ
/// (userAllergens'le kesişmiş) kümeler seviyesinde ayrıca yapılır.
enum WarningSentenceAllergenMerger {
    static func merge(
        result: ProductCheckResult,
        warningDetection: IngredientDetectionResult?,
        userAllergens: Set<Allergen>
    ) -> ProductCheckResult {
        guard let warningDetection,
              !result.isCosmeticNotSupported,
              !result.isProfileEmpty
        else { return result }

        let warningMatchedAllergens = warningDetection.contains.intersection(userAllergens)
        let warningMatchedTraces = warningDetection.mayContain.intersection(userAllergens)

        let mergedMatchedAllergens = result.matchedAllergens.union(warningMatchedAllergens)
        let mergedMatchedTraces = result.matchedTraces.union(warningMatchedTraces).subtracting(mergedMatchedAllergens)

        guard mergedMatchedAllergens != result.matchedAllergens || mergedMatchedTraces != result.matchedTraces else {
            return result
        }

        // Sadece uyarıdan YENİ eklenen alerjenler için "neden" yazılır; metinden zaten
        // eşleşmiş olan bir alerjenin kendi (daha spesifik) nedeni korunur.
        var reasons = result.allergenReasons
        for allergen in mergedMatchedAllergens.union(mergedMatchedTraces) where reasons[allergen] == nil {
            reasons[allergen] = warningDetection.reasons[allergen]
        }

        let status: CheckStatus
        if !mergedMatchedAllergens.isEmpty || !result.matchedCustomTerms.isEmpty {
            status = .unsafe
        } else if !mergedMatchedTraces.isEmpty {
            status = .caution
        } else {
            status = result.status
        }

        return ProductCheckResult(
            product: result.product,
            status: status,
            matchedAllergens: mergedMatchedAllergens,
            matchedTraces: mergedMatchedTraces,
            detectedFromIngredients: result.detectedFromIngredients,
            matchedCustomTerms: result.matchedCustomTerms,
            isCosmeticNotSupported: result.isCosmeticNotSupported,
            isProfileEmpty: result.isProfileEmpty,
            isMissingIngredientsHeading: result.isMissingIngredientsHeading,
            allergenReasons: reasons
        )
    }
}
