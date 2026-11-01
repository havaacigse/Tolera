import Foundation

/// Temkinli ilke: "içindekiler" başlığı metinde hiç bulunamadıysa (ör. OCR sadece
/// üretim yeri/adres kısmını okumuş olabilir), analiz edilen metnin güvenilirliği
/// belirsizdir. Bu durumda sonuç ASLA "safe" olamaz — gerçekten alerjen eşleştiyse
/// (unsafe/caution) bu geçerliliğini korur, ama "hiçbir şey bulunamadı" sonucu
/// yanlışlıkla "güvenli" yerine "yetersiz bilgi" olarak işaretlenir.
///
/// `CheckIngredientsTextUseCase`'den (tek seferlik OCR kontrolü) çıkarıldı ki barkod
/// hafızasından veya tarama geçmişinden yeniden hesaplanan OCR kaynaklı sonuçlara da
/// (ürünün OFF'tan gelen kategori/marka bilgisiyle birlikte) aynı kural uygulanabilsin.
enum MissingIngredientsHeadingRule {
    static func apply(to result: ProductCheckResult, headingFound: Bool) -> ProductCheckResult {
        guard !headingFound, result.status == .safe else { return result }

        return ProductCheckResult(
            product: result.product,
            status: .unknown,
            matchedAllergens: result.matchedAllergens,
            matchedTraces: result.matchedTraces,
            detectedFromIngredients: result.detectedFromIngredients,
            matchedCustomTerms: result.matchedCustomTerms,
            isCosmeticNotSupported: result.isCosmeticNotSupported,
            isProfileEmpty: result.isProfileEmpty,
            isMissingIngredientsHeading: true,
            allergenReasons: result.allergenReasons
        )
    }
}
