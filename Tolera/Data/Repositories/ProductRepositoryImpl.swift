import Foundation

final class ProductRepositoryImpl: ProductRepository {
    // search-a-licious ingredients_text/allergens_tags gibi alanları güvenilir döndürmez;
    // bu yüzden aramadan en fazla bu kadar aday için tam ürün detayı (ayrı istek) çekilir.
    private static let maxCandidateDetailFetches = 10
    private static let searchPageSize = 20
    // OFF'un dakikalık istek sınırını zorlamamak için detay istekleri aynı anda en fazla
    // bu kadar paralel yapılır.
    private static let maxConcurrentDetailFetches = 5

    private let foodService: OpenFoodFactsService
    private let beautyService: OpenFoodFactsService
    private let searchService: OpenFoodFactsSearchService

    // Aynı kategori için oturum boyunca tekrar arama yapılmasın diye bellekte önbelleklenir.
    private var categoryCache: [String: [Product]] = [:]

    init(
        foodService: OpenFoodFactsService = OpenFoodFactsService(),
        beautyService: OpenFoodFactsService = OpenFoodFactsService(baseURL: "https://world.openbeautyfacts.org"),
        searchService: OpenFoodFactsSearchService = OpenFoodFactsSearchService()
    ) {
        self.foodService = foodService
        self.beautyService = beautyService
        self.searchService = searchService
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

    func products(inCategory category: String, excludingBarcode barcode: String) async throws -> [Product] {
        let candidates = try await cachedCandidates(forCategory: category)
        return candidates.filter { $0.barcode != barcode }
    }

    /// Verilen kategori daha önce aranmadıysa arayıp sonucu önbelleğe alır; aranmışsa
    /// doğrudan önbellekten döner (ağ isteği yapılmaz).
    private func cachedCandidates(forCategory category: String) async throws -> [Product] {
        if let cached = categoryCache[category] {
            return cached
        }

        let barcodes = try await searchService.searchBarcodes(category: category, pageSize: Self.searchPageSize)
        let candidateBarcodes = Array(barcodes.prefix(Self.maxCandidateDetailFetches))

        let candidates = await fetchProductDetails(forBarcodes: candidateBarcodes)

        categoryCache[category] = candidates
        return candidates
    }

    /// Aday barkodların tam ürün detayını en fazla `maxConcurrentDetailFetches` eşzamanlı
    /// istekle çeker. Sonuç dizisi, tamamlanma sırası değil aramadan gelen popülerlik
    /// sırası korunarak döndürülür; detayı alınamayan (ör. kaldırılmış) ürünler atlanır.
    private func fetchProductDetails(forBarcodes barcodes: [String]) async -> [Product] {
        var productsByIndex: [Int: Product] = [:]

        await withTaskGroup(of: (Int, Product?).self) { group in
            var nextIndex = 0

            func addTask() {
                guard nextIndex < barcodes.count else { return }
                let index = nextIndex
                let barcode = barcodes[index]
                nextIndex += 1
                group.addTask {
                    let product = try? await self.product(barcode: barcode)
                    return (index, product)
                }
            }

            for _ in 0..<min(Self.maxConcurrentDetailFetches, barcodes.count) {
                addTask()
            }

            for await (index, product) in group {
                if let product {
                    productsByIndex[index] = product
                }
                addTask()
            }
        }

        return barcodes.indices.compactMap { productsByIndex[$0] }
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
