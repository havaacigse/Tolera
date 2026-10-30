import Observation

@Observable
final class SearchViewModel {
    var barcode: String = "8680181000017"
    var isLoading = false
    var result: ProductCheckResult?
    var errorMessage: String?

    private let productRepository: ProductRepository
    private let profileRepository: UserProfileRepository
    private let checkProductUseCase: CheckProductUseCase

    init(
        productRepository: ProductRepository,
        profileRepository: UserProfileRepository,
        checkProductUseCase: CheckProductUseCase
    ) {
        self.productRepository = productRepository
        self.profileRepository = profileRepository
        self.checkProductUseCase = checkProductUseCase
    }

    func handleScannedBarcode(_ code: String) {
        barcode = code
        search()
    }

    func search() {
        errorMessage = nil
        result = nil
        isLoading = true

        Task {
            do {
                let product = try await productRepository.product(barcode: barcode)
                let userAllergens = profileRepository.loadAllergens()
                let customTerms = profileRepository.loadCustomTerms()
                result = checkProductUseCase.execute(
                    product: product,
                    userAllergens: userAllergens,
                    customTerms: customTerms
                )
            } catch let error as ProductError {
                errorMessage = message(for: error)
            } catch {
                errorMessage = "Bilinmeyen hata."
            }
            isLoading = false
        }
    }

    private func message(for error: ProductError) -> String {
        switch error {
        case .notFound:
            return "Ürün bulunamadı."
        case .network:
            return "İnternet bağlantısı yok."
        case .unknown:
            return "Bilinmeyen hata."
        }
    }
}
