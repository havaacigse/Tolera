import Observation

@Observable
final class SearchViewModel {
    var barcode: String = "8680181000017"
    var isLoading = false
    var result: ProductCheckResult?
    var errorMessage: String?
    var isProductNotFound = false

    var alternatives: [Product]?
    var isLoadingAlternatives = false
    var alternativesLoadFailed = false

    private let productRepository: ProductRepository
    private let profileRepository: UserProfileRepository
    private let checkProductUseCase: CheckProductUseCase
    private let findAlternativesUseCase: FindAlternativesUseCase

    init(
        productRepository: ProductRepository,
        profileRepository: UserProfileRepository,
        checkProductUseCase: CheckProductUseCase,
        findAlternativesUseCase: FindAlternativesUseCase
    ) {
        self.productRepository = productRepository
        self.profileRepository = profileRepository
        self.checkProductUseCase = checkProductUseCase
        self.findAlternativesUseCase = findAlternativesUseCase
    }

    func handleScannedBarcode(_ code: String) {
        barcode = code
        search()
    }

    func search() {
        errorMessage = nil
        isProductNotFound = false
        result = nil
        isLoading = true
        alternatives = nil
        alternativesLoadFailed = false

        Task {
            do {
                let product = try await productRepository.product(barcode: barcode)
                let userAllergens = profileRepository.loadAllergens()
                let customTerms = profileRepository.loadCustomTerms()
                let checkResult = checkProductUseCase.execute(
                    product: product,
                    userAllergens: userAllergens,
                    customTerms: customTerms
                )
                result = checkResult
                isLoading = false

                if checkResult.status == .unsafe || checkResult.status == .caution {
                    await fetchAlternatives(
                        for: product,
                        status: checkResult.status,
                        userAllergens: userAllergens,
                        customTerms: customTerms
                    )
                }
                return
            } catch ProductError.notFound {
                isProductNotFound = true
            } catch let error as ProductError {
                errorMessage = message(for: error)
            } catch {
                errorMessage = "Bilinmeyen hata."
            }
            isLoading = false
        }
    }

    /// Alternatif bulunamama (boş liste) ile arama başarısız olma (ağ hatası) durumlarını
    /// UI'da ayırt edebilmek için ayrı bir "yüklenemedi" bayrağı tutulur.
    private func fetchAlternatives(
        for product: Product,
        status: CheckStatus,
        userAllergens: Set<Allergen>,
        customTerms: [String]
    ) async {
        isLoadingAlternatives = true

        do {
            alternatives = try await findAlternativesUseCase.execute(
                for: product,
                currentStatus: status,
                userAllergens: userAllergens,
                customTerms: customTerms
            )
        } catch {
            alternativesLoadFailed = true
        }

        isLoadingAlternatives = false
    }

    func makeDetailViewModel(for product: Product) -> ProductDetailViewModel {
        ProductDetailViewModel(
            product: product,
            checkProductUseCase: checkProductUseCase,
            profileRepository: profileRepository
        )
    }

    private func message(for error: ProductError) -> String {
        switch error {
        case .notFound:
            return "Bu ürün veritabanında bulunamadı."
        case .network:
            return "İnternet bağlantısı yok."
        case .unknown:
            return "Bilinmeyen hata."
        }
    }
}
