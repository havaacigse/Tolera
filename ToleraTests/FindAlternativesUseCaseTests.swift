import Testing
@testable import Tolera

struct FindAlternativesUseCaseTests {
    private struct MockNetworkError: Error {}

    private final class MockProductRepository: ProductRepository, @unchecked Sendable {
        var categoryResults: [String: [Product]] = [:]
        var categoryErrors: [String: Error] = [:]
        private(set) var requestedCategories: [String] = []

        func product(barcode: String) async throws -> Product {
            throw ProductError.notFound
        }

        func products(inCategory category: String, excludingBarcode barcode: String) async throws -> [Product] {
            requestedCategories.append(category)
            if let error = categoryErrors[category] {
                throw error
            }
            return categoryResults[category] ?? []
        }
    }

    private func makeProduct(
        barcode: String,
        allergens: Set<Allergen> = [],
        traces: Set<Allergen> = [],
        ingredientsText: String? = "su, şeker",
        categories: [String] = ["en:snacks", "en:biscuits"]
    ) -> Product {
        Product(
            barcode: barcode,
            name: "Ürün \(barcode)",
            brand: "Marka",
            imageURL: nil,
            ingredientsText: ingredientsText,
            allergens: allergens,
            traces: traces,
            categories: categories,
            type: .food
        )
    }

    @Test func safeDurumundaAramaYapilmaz() async throws {
        let repository = MockProductRepository()
        let useCase = FindAlternativesUseCase(productRepository: repository)
        let product = makeProduct(barcode: "1")

        let result = try await useCase.execute(for: product, currentStatus: .safe, userAllergens: [.milk], customTerms: [])

        #expect(result.isEmpty)
        #expect(repository.requestedCategories.isEmpty)
    }

    @Test func unknownDurumundaAramaYapilmaz() async throws {
        let repository = MockProductRepository()
        let useCase = FindAlternativesUseCase(productRepository: repository)
        let product = makeProduct(barcode: "1")

        let result = try await useCase.execute(for: product, currentStatus: .unknown, userAllergens: [.milk], customTerms: [])

        #expect(result.isEmpty)
        #expect(repository.requestedCategories.isEmpty)
    }

    @Test func unsafeVeUnknownAdaylarElenirSadeceSafeOlanlarDoner() async throws {
        let repository = MockProductRepository()
        repository.categoryResults["en:biscuits"] = [
            makeProduct(barcode: "safe-1", ingredientsText: "şeker, su"),
            makeProduct(barcode: "unsafe-1", allergens: [.milk], ingredientsText: "süt"),
            makeProduct(barcode: "unknown-1", ingredientsText: nil)
        ]
        let useCase = FindAlternativesUseCase(productRepository: repository)
        let product = makeProduct(barcode: "original")

        let result = try await useCase.execute(for: product, currentStatus: .unsafe, userAllergens: [.milk], customTerms: [])

        #expect(result.map(\.barcode) == ["safe-1"])
    }

    @Test func ayniBarkodHaricTutulur() async throws {
        let repository = MockProductRepository()
        repository.categoryResults["en:biscuits"] = [
            makeProduct(barcode: "original", ingredientsText: "şeker, su"),
            makeProduct(barcode: "safe-1", ingredientsText: "şeker, su")
        ]
        let useCase = FindAlternativesUseCase(productRepository: repository)
        let product = makeProduct(barcode: "original")

        let result = try await useCase.execute(for: product, currentStatus: .caution, userAllergens: [.milk], customTerms: [])

        #expect(result.map(\.barcode) == ["safe-1"])
    }

    @Test func enFazlaBesSonucDonerVeFazlasiIcinAramaYapmaz() async throws {
        let repository = MockProductRepository()
        repository.categoryResults["en:biscuits"] = (1...7).map {
            makeProduct(barcode: "safe-\($0)", ingredientsText: "şeker, su")
        }
        let useCase = FindAlternativesUseCase(productRepository: repository)
        let product = makeProduct(barcode: "original")

        let result = try await useCase.execute(for: product, currentStatus: .unsafe, userAllergens: [.milk], customTerms: [])

        #expect(result.count == 5)
        #expect(repository.requestedCategories == ["en:biscuits"])
    }

    @Test func yeterliSonucYoksaUstKategoriyeCikar() async throws {
        let repository = MockProductRepository()
        repository.categoryResults["en:biscuits"] = [
            makeProduct(barcode: "safe-1", ingredientsText: "şeker, su")
        ]
        repository.categoryResults["en:snacks"] = [
            makeProduct(barcode: "safe-2", ingredientsText: "şeker, su"),
            makeProduct(barcode: "safe-3", ingredientsText: "şeker, su")
        ]
        let useCase = FindAlternativesUseCase(productRepository: repository)
        let product = makeProduct(barcode: "original", categories: ["en:snacks", "en:biscuits"])

        let result = try await useCase.execute(for: product, currentStatus: .unsafe, userAllergens: [.milk], customTerms: [])

        #expect(Set(result.map(\.barcode)) == ["safe-1", "safe-2", "safe-3"])
        #expect(repository.requestedCategories == ["en:biscuits", "en:snacks"])
    }

    @Test func enFazlaIkiUstSeviyeyeCikar() async throws {
        let repository = MockProductRepository()
        // Hiçbir kategoride yeterli sonuç yok; en fazla 3 kategori (en spesifik + 2 üst) denenmeli.
        let useCase = FindAlternativesUseCase(productRepository: repository)
        let product = makeProduct(
            barcode: "original",
            categories: ["en:foods", "en:snacks", "en:sweet-snacks", "en:biscuits"]
        )

        let result = try await useCase.execute(for: product, currentStatus: .unsafe, userAllergens: [], customTerms: [])

        #expect(result.isEmpty)
        #expect(repository.requestedCategories == ["en:biscuits", "en:sweet-snacks", "en:snacks"])
    }

    @Test func tumKategorilerAgHatasiVerirseHataFirlatir() async {
        let repository = MockProductRepository()
        repository.categoryErrors["en:biscuits"] = MockNetworkError()
        repository.categoryErrors["en:snacks"] = MockNetworkError()
        let useCase = FindAlternativesUseCase(productRepository: repository)
        let product = makeProduct(barcode: "original", categories: ["en:snacks", "en:biscuits"])

        await #expect(throws: FindAlternativesError.loadFailed) {
            try await useCase.execute(for: product, currentStatus: .unsafe, userAllergens: [.milk], customTerms: [])
        }
    }

    @Test func birKategoriBasarisizOlsaDaDigeriBasariliysaHataFirlatmaz() async throws {
        let repository = MockProductRepository()
        repository.categoryErrors["en:biscuits"] = MockNetworkError()
        repository.categoryResults["en:snacks"] = [
            makeProduct(barcode: "safe-1", ingredientsText: "şeker, su")
        ]
        let useCase = FindAlternativesUseCase(productRepository: repository)
        let product = makeProduct(barcode: "original", categories: ["en:snacks", "en:biscuits"])

        let result = try await useCase.execute(for: product, currentStatus: .unsafe, userAllergens: [.milk], customTerms: [])

        #expect(result.map(\.barcode) == ["safe-1"])
    }
}
