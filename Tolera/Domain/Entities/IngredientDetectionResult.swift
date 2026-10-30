import Foundation

/// `IngredientAllergenDetector`'ın metin analizi sonucu.
struct IngredientDetectionResult {
    /// Metinde gerçek içerik olarak geçen alerjenler.
    let contains: Set<Allergen>
    /// Metinde sadece eser miktar uyarısı olarak geçen alerjenler ("içerebilir", "may contain" vb.).
    let mayContain: Set<Allergen>
    /// Metin Türkçe ya da İngilizce değilse (ör. Arapça, Rusça) true olur; bu durumda
    /// contains/mayContain boştur, metin analiz edilmemiştir.
    let isUnrecognizedLanguage: Bool
    /// Her bulunan alerjen için onu tetikleyen metindeki ifade (ör. .gluten → "buğday unu").
    let reasons: [Allergen: String]
}
