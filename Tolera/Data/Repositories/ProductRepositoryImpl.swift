import Foundation

final class ProductRepositoryImpl: ProductRepository {
    private let foodService: OpenFoodFactsService
    private let beautyService: OpenFoodFactsService

    init(
        foodService: OpenFoodFactsService = OpenFoodFactsService(),
        beautyService: OpenFoodFactsService = OpenFoodFactsService(baseURL: "https://world.openbeautyfacts.org")
    ) {
        self.foodService = foodService
        self.beautyService = beautyService
    }

    func product(barcode: String) async throws -> Product {
        do {
            let dto = try await foodService.fetchProduct(barcode: barcode)
            return try domainProduct(from: dto)
        } catch OFFServiceError.productNotFound {
            do {
                let dto = try await beautyService.fetchProduct(barcode: barcode)
                return try domainProduct(from: dto)
            } catch {
                throw map(error)
            }
        } catch {
            throw map(error)
        }
    }

    private func domainProduct(from dto: OFFProductDTO) throws -> Product {
        guard let product = dto.toDomain() else {
            throw ProductError.notFound
        }
        return product
    }

    private func map(_ error: Error) -> ProductError {
        guard let offError = error as? OFFServiceError else {
            return .unknown
        }
        switch offError {
        case .productNotFound:
            return .notFound
        case .network:
            return .network
        case .invalidResponse, .decoding:
            return .unknown
        }
    }
}
