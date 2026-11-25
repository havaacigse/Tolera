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

    /// Sonuç barkod hafızasından (OFF'a gidilmeden) üretildiyse buraya yazılır; `SearchView`
    /// bunu "Kaynak: daha önce okuduğun ambalaj (tarih)" + "Yeniden oku" olarak gösterir.
    /// Hafızada kayıt yoksa (normal OFF akışı) nil'dir.
    var savedIngredientsTextSource: SavedIngredientsText?

    private let productRepository: ProductRepository
    private let profileRepository: UserProfileRepository
    private let checkProductUseCase: CheckProductUseCase
    private let findAlternativesUseCase: FindAlternativesUseCase
    private let textRecognitionService: TextRecognitionService
    private let savedIngredientsTextRepository: SavedIngredientsTextRepository
    private let checkIngredientsTextUseCase: CheckIngredientsTextUseCase

    init(
        productRepository: ProductRepository,
        profileRepository: UserProfileRepository,
        checkProductUseCase: CheckProductUseCase,
        findAlternativesUseCase: FindAlternativesUseCase,
        textRecognitionService: TextRecognitionService,
        savedIngredientsTextRepository: SavedIngredientsTextRepository,
        checkIngredientsTextUseCase: CheckIngredientsTextUseCase = CheckIngredientsTextUseCase()
    ) {
        self.productRepository = productRepository
        self.profileRepository = profileRepository
        self.checkProductUseCase = checkProductUseCase
        self.findAlternativesUseCase = findAlternativesUseCase
        self.textRecognitionService = textRecognitionService
        self.savedIngredientsTextRepository = savedIngredientsTextRepository
        self.checkIngredientsTextUseCase = checkIngredientsTextUseCase
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
        savedIngredientsTextSource = nil

        let userAllergens = profileRepository.loadAllergens()
        let customTerms = profileRepository.loadCustomTerms()

        // Barkod hafızasında (daha önce OCR ile okunup kaydedilmiş) bu barkod için kayıt
        // varsa, OFF'a hiç gidilmez; sonuç doğrudan o metinden üretilir.
        if let saved = savedIngredientsTextRepository.find(barcode: barcode) {
            savedIngredientsTextSource = saved
            result = checkIngredientsTextUseCase.execute(
                rawText: saved.ingredientsText,
                userAllergens: userAllergens,
                customTerms: customTerms,
                headingFound: saved.headingFound,
                barcode: saved.barcode,
                brand: saved.brand,
                imageURL: saved.imageURL,
                categories: saved.categories
            )
            isLoading = false
            return
        }

        Task {
            do {
                let product = try await productRepository.product(barcode: barcode)
                let checkResult = checkProductUseCase.execute(
                    product: product,
                    userAllergens: userAllergens,
                    customTerms: customTerms
                )
                result = checkResult
                isLoading = false

                if FeatureFlags.alternativeSuggestionsEnabled,
                   checkResult.status == .unsafe || checkResult.status == .caution {
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

    /// `barcode` verilirse (ör. "Yeniden oku"), OCR ekranı bu barkodu bilir — ileride
    /// o metni aynı barkodla hafızaya kaydedebilsin diye (bkz. Aşama 3, Adım C).
    func makeIngredientsScanViewModel(barcode: String? = nil) -> IngredientsScanViewModel {
        IngredientsScanViewModel(
            textRecognitionService: textRecognitionService,
            profileRepository: profileRepository,
            barcode: barcode
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
