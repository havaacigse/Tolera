import Foundation

enum ProductError: Error {
    case notFound
    case network
    case unknown
}

protocol ProductRepository {
    func product(barcode: String) async throws -> Product
}
