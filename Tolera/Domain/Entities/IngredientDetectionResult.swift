import Foundation

/// `IngredientAllergenDetector`'ın metin analizi sonucu.
struct IngredientDetectionResult {
    /// Metinde gerçek içerik olarak geçen alerjenler.
    let contains: Set<Allergen>
    /// Metinde sadece eser miktar uyarısı olarak geçen alerjenler ("içerebilir", "may contain" vb.).
    let mayContain: Set<Allergen>
}
