import Foundation

/// OFF'un search-a-licious arama API'sini (dünya genelinde farklı bir host:
/// search.openfoodfacts.org) kategoriye göre ürün aramak için kullanır.
/// Bu API ingredients_text/allergens_tags gibi alanları güvenilir dönmediğinden
/// sadece barkod listesi alınır; tam veri `OpenFoodFactsService` ile tamamlanır.
final class OpenFoodFactsSearchService {
    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = "https://search.openfoodfacts.org", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Türkiye'de satılan, verilen kategorideki, içindekiler metni dolu olduğu işaretli
    /// ("en:ingredients-completed") ürünlerin barkodlarını popülerliğe göre sıralı döndürür.
    /// Bu filtre, detay isteklerini boşa harcamamak için içindekiler metni olmayan
    /// ürünleri daha arama aşamasında eler (sonra zaten `unknown` sayılıp önerilmeyeceklerdi).
    func searchBarcodes(category: String, pageSize: Int) async throws -> [String] {
        var components = URLComponents(string: baseURL + "/search")
        components?.queryItems = [
            URLQueryItem(
                name: "q",
                value: "countries_tags:\"en:turkey\" AND categories_tags:\"\(category)\" AND states_tags:\"en:ingredients-completed\""
            ),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "sort_by", value: "popularity_key"),
            URLQueryItem(name: "fields", value: "code")
        ]

        guard let url = components?.url else {
            throw OFFServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Tolera/0.1 (iOS; bitirme projesi)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OFFServiceError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw OFFServiceError.invalidResponse
        }

        let decoded: OFFCategorySearchResponseDTO
        do {
            decoded = try JSONDecoder().decode(OFFCategorySearchResponseDTO.self, from: data)
        } catch {
            throw OFFServiceError.decoding(error)
        }

        return decoded.hits.compactMap(\.code)
    }
}
