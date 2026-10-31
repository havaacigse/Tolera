import Foundation

enum ProductError: Error {
    case notFound
    case network
    case unknown
}

protocol ProductRepository {
    func product(barcode: String) async throws -> Product

    /// Aynı kategorideki ürünleri (popülerliğe göre) döndürür; verilen barkod hariç tutulur.
    func products(inCategory category: String, excludingBarcode barcode: String) async throws -> [Product]
}
