import Foundation

/// OFF search-a-licious API'sinin kategori arama cevabı. Arama sonuçları
/// ingredients_text/allergens_tags gibi alanları güvenilir biçimde döndürmediği
/// için sadece barkodu okuyoruz; ürünün tam verisi ayrıca ürün detayı
/// endpoint'inden çekilir (bkz. `OpenFoodFactsSearchService`).
struct OFFCategorySearchResponseDTO: Decodable {
    let hits: [Hit]

    struct Hit: Decodable {
        let code: String?
    }
}
