import Foundation

/// Bir geçmiş kaydını kullanıcının GÜNCEL profiliyle yeniden hesaplar. `snapshotStatus`
/// tarama anındaki sonuçtur; profil o zamandan beri değişmiş olabileceğinden geçmiş
/// ekranında bir kayda dokunulduğunda bu use case çağrılır.
struct RecheckScanHistoryEntryUseCase {
    private let checkProductUseCase: CheckProductUseCase

    init(checkProductUseCase: CheckProductUseCase = CheckProductUseCase()) {
        self.checkProductUseCase = checkProductUseCase
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

        switch entry.source {
        case .off:
            return result
        case .ocrPhoto:
            // OCR kaynaklı kayıtlarda, kaydedildiği anda "içindekiler" başlığı
            // bulunamamışsa aynı temkinli kural burada da uygulanır (bkz.
            // `MissingIngredientsHeadingRule`).
            return MissingIngredientsHeadingRule.apply(to: result, headingFound: entry.headingFound)
        }
    }
}
