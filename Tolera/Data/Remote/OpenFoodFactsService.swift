import Foundation

enum OFFServiceError: Error {
    case productNotFound
    case invalidResponse
    case network(Error)
    case decoding(Error)
}

final class OpenFoodFactsService {
    private static let fields = "code,product_name,product_name_tr,brands,image_front_url,ingredients_text,ingredients_text_tr,allergens_tags,traces_tags,categories_tags,product_type"

    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = "https://world.openfoodfacts.org", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchProduct(barcode: String) async throws -> OFFProductDTO {
        var components = URLComponents(string: baseURL + "/api/v2/product/\(barcode)")
        components?.queryItems = [URLQueryItem(name: "fields", value: Self.fields)]

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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OFFServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw OFFServiceError.productNotFound
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OFFServiceError.invalidResponse
        }

        let decoded: OFFProductResponseDTO
        do {
            decoded = try JSONDecoder().decode(OFFProductResponseDTO.self, from: data)
        } catch {
            throw OFFServiceError.decoding(error)
        }

        guard decoded.status != 0, let product = decoded.product else {
            throw OFFServiceError.productNotFound
        }

        return product
    }
}
