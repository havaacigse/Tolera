import Foundation

/// Bir geçmiş kaydını kullanıcının GÜNCEL profiliyle yeniden hesaplar. `snapshotStatus`
/// tarama anındaki sonuçtur; profil o zamandan beri değişmiş olabileceğinden geçmiş
/// ekranında bir kayda dokunulduğunda bu use case çağrılır.
struct RecheckScanHistoryEntryUseCase {
    private let checkProductUseCase: CheckProductUseCase
    private let detector: IngredientAllergenDetector

    init(
        checkProductUseCase: CheckProductUseCase = CheckProductUseCase(),
        detector: IngredientAllergenDetector = IngredientAllergenDetector()
    ) {
        self.checkProductUseCase = checkProductUseCase
        self.detector = detector
    }

    func execute(
        entry: ScanHistoryEntry,
        userAllergens: Set<Allergen>,
        customTerms: [String] = []
    ) -> ProductCheckResult {
        let product = Product(
            barcode: entry.barcode ?? "",
            name: entry.productName,
            brand: entry.brand,
            imageURL: entry.imageURL,
            ingredientsText: entry.ingredientsText,
            allergens: entry.allergens,
            traces: entry.traces,
            categories: entry.categories,
            type: entry.type
        )

        let result = checkProductUseCase.execute(
            product: product,
            userAllergens: userAllergens,
            customTerms: customTerms
        )

        // `entry.rawText` varsa (OCR kaynaklı kayıt), başlık/besin tablosu penceresinin
        // dışında kalan alerjen uyarıları yeniden taranır — yoksa ilk taramada yakalanan
        // bir uyarı, geçmişten yeniden hesaplarken kaçırılabilir.
        let warningDetection = entry.rawText.map(detector.detectWarningSentences)
        let mergedResult = WarningSentenceAllergenMerger.merge(
            result: result,
            warningDetection: warningDetection,
            userAllergens: userAllergens
        )

        switch entry.source {
        case .off:
            return mergedResult
        case .ocrPhoto:
            // OCR kaynaklı kayıtlarda, kaydedildiği anda "içindekiler" başlığı
            // bulunamamışsa aynı temkinli kural burada da uygulanır (bkz.
            // `MissingIngredientsHeadingRule`).
            return MissingIngredientsHeadingRule.apply(to: mergedResult, headingFound: entry.headingFound)
        }
    }
}
