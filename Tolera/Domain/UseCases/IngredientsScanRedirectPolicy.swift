import Foundation

/// Barkod taramasından sonra kullanıcıyı doğrudan "İçindekileri Fotoğrafla" ekranına
/// yönlendirip yönlendirmeme kararını tek bir yerde toplar (bkz. `SearchViewModel`).
///
/// Yönlendirilir: ürün OFF'ta hiç bulunamadıysa, VEYA ürün bulundu ama içindekiler
/// metni boşsa, VEYA metin var ama dil anlaşılamadığı için sonuç "unknown" döndüyse.
/// Yönlendirilmez: kozmetik ürünse (henüz desteklenmiyor) veya kullanıcının profili
/// boşsa (önce profil uyarısı gösterilmeli, OCR'a gitmek anlamsız olur).
enum IngredientsScanRedirectPolicy {
    static func shouldRedirectToIngredientsScan(
        isProductNotFound: Bool,
        result: ProductCheckResult?,
        isProfileEmpty: Bool
    ) -> Bool {
        guard !isProfileEmpty else { return false }

        if isProductNotFound { return true }

        guard let result, !result.isCosmeticNotSupported else { return false }

        if result.product.ingredientsText?.isEmpty ?? true { return true }

        // Bu noktada metin var, kozmetik değil, profil boş değil: kalan tek "unknown"
        // sebebi dil anlaşılamaması olabilir (bkz. `IngredientAllergenDetector`).
        return result.status == .unknown
    }
}
