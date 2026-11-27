import Foundation
import Observation

/// Otomatik (veya "Yeniden oku" ile) OCR ekranına geçişte taşınan bağlam. `productName`/
/// `brand`/`imageURL`/`categories` ürün OFF'ta bulunup sadece içindekiler eksikse bilinir;
/// ürün hiç bulunamadıysa sadece `barcode` dolu olur.
struct IngredientsScanContext: Hashable {
    let barcode: String
    let productName: String?
    let brand: String?
    let imageURL: URL?
    let categories: [String]
}

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

    /// Dolu olduğunda `SearchView` otomatik olarak OCR ekranına geçer (bkz.
    /// `IngredientsScanRedirectPolicy`). Kullanıcı o ekrandan fotoğraf çekmeden geri dönerse
    /// SwiftUI'nin `navigationDestination(item:)` mekanizması bunu kendiliğinden nil'e
    /// çevirir; `search()` dışında hiçbir yer bunu tekrar dolduramaz, bu yüzden bir arama
    /// için en fazla bir kez tetiklenir.
    var pendingIngredientsScanContext: IngredientsScanContext?

    /// Yönlendirme tetiklendiğinde geçmişe HENÜZ kaydedilmemiş, "ara" unknown/bulunamadı
    /// sonucunu kaydedecek kapanış. Kullanıcı OCR'dan fotoğraf çekmeden vazgeçerse
    /// (`ingredientsScanDismissedWithoutCompleting`) bu çalışır; OCR başarıyla bir sonuç
    /// üretirse (`ingredientsScanDidProduceResult`) bunun yerine o kaydedilir ve bu iptal edilir.
    private var deferredHistoryLogAction: (() -> Void)?

    private let productRepository: ProductRepository
    private let profileRepository: UserProfileRepository
    private let checkProductUseCase: CheckProductUseCase
    private let findAlternativesUseCase: FindAlternativesUseCase
    private let textRecognitionService: TextRecognitionService
    private let savedIngredientsTextRepository: SavedIngredientsTextRepository
    private let scanHistoryRepository: ScanHistoryRepository
    private let checkIngredientsTextUseCase: CheckIngredientsTextUseCase

    init(
        productRepository: ProductRepository,
        profileRepository: UserProfileRepository,
        checkProductUseCase: CheckProductUseCase,
        findAlternativesUseCase: FindAlternativesUseCase,
        textRecognitionService: TextRecognitionService,
        savedIngredientsTextRepository: SavedIngredientsTextRepository,
        scanHistoryRepository: ScanHistoryRepository,
        checkIngredientsTextUseCase: CheckIngredientsTextUseCase = CheckIngredientsTextUseCase()
    ) {
        self.productRepository = productRepository
        self.profileRepository = profileRepository
        self.checkProductUseCase = checkProductUseCase
        self.findAlternativesUseCase = findAlternativesUseCase
        self.textRecognitionService = textRecognitionService
        self.savedIngredientsTextRepository = savedIngredientsTextRepository
        self.scanHistoryRepository = scanHistoryRepository
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
        pendingIngredientsScanContext = nil
        deferredHistoryLogAction = nil

        let userAllergens = profileRepository.loadAllergens()
        let customTerms = profileRepository.loadCustomTerms()
        let isProfileEmpty = userAllergens.isEmpty && customTerms.isEmpty

        // Barkod hafızasında (daha önce OCR ile okunup kaydedilmiş) bu barkod için kayıt
        // varsa, OFF'a hiç gidilmez; sonuç doğrudan o metinden üretilir.
        if let saved = savedIngredientsTextRepository.find(barcode: barcode) {
            savedIngredientsTextSource = saved
            let checkResult = computeResult(from: saved, userAllergens: userAllergens, customTerms: customTerms)
            result = checkResult
            isLoading = false
            // Hafıza yolu yönlendirmeye hiç girmez (Adım B'nin kapsamı sadece OFF yolu);
            // bu yüzden sonuç her zaman kesindir ve hemen kaydedilir.
            logToHistory(product: checkResult.product, result: checkResult, source: .ocrPhoto, rawText: saved.rawText)
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

                if IngredientsScanRedirectPolicy.shouldRedirectToIngredientsScan(
                    isProductNotFound: false,
                    result: checkResult,
                    isProfileEmpty: isProfileEmpty
                ) {
                    pendingIngredientsScanContext = IngredientsScanContext(
                        barcode: product.barcode,
                        productName: product.name,
                        brand: product.brand,
                        imageURL: product.imageURL,
                        categories: product.categories
                    )
                    // "unknown" ara sonuçtur: OCR'a yönlendirilirken henüz kaydedilmez.
                    // Kullanıcı fotoğraf çekmeden vazgeçerse bu, o anda son sonuç olur.
                    deferredHistoryLogAction = { [weak self] in
                        self?.logToHistory(product: product, result: checkResult, source: .off)
                    }
                } else {
                    logToHistory(product: product, result: checkResult, source: .off)

                    if FeatureFlags.alternativeSuggestionsEnabled,
                       checkResult.status == .unsafe || checkResult.status == .caution {
                        await fetchAlternatives(
                            for: product,
                            status: checkResult.status,
                            userAllergens: userAllergens,
                            customTerms: customTerms
                        )
                    }
                }
                return
            } catch ProductError.notFound {
                isProductNotFound = true
                isLoading = false

                if IngredientsScanRedirectPolicy.shouldRedirectToIngredientsScan(
                    isProductNotFound: true,
                    result: nil,
                    isProfileEmpty: isProfileEmpty
                ) {
                    let notFoundBarcode = self.barcode
                    pendingIngredientsScanContext = IngredientsScanContext(
                        barcode: notFoundBarcode,
                        productName: nil,
                        brand: nil,
                        imageURL: nil,
                        categories: []
                    )
                    deferredHistoryLogAction = { [weak self] in
                        self?.logNotFoundToHistory(barcode: notFoundBarcode)
                    }
                }
                // Profil boşsa (redirect policy'nin tek engeli) hiçbir şey kaydedilmez —
                // anlamlı bir alerjen bilgisi üretilmedi.
                return
            } catch let error as ProductError {
                errorMessage = message(for: error)
            } catch {
                errorMessage = "Bilinmeyen hata."
            }
            isLoading = false
        }
    }

    /// "Tüm verilerimi sil" sonrası çağrılır. Bu ViewModel uygulama ömrü boyunca TEK bir
    /// örnek olarak yaşar; silme sonrası ekrana (yeniden onboarding'den geçip) dönüldüğünde,
    /// yeni bir arama yapılmadan `result`/`savedIngredientsTextSource` gibi alanlarda eski
    /// (silinen profille hesaplanmış) bir sonuç görünür kalmasın. Değerler, `barcode` dahil,
    /// yeni oluşturulmuş bir `SearchViewModel`'in başlangıç durumuna döndürülür.
    func reset() {
        barcode = "8680181000017"
        isLoading = false
        result = nil
        errorMessage = nil
        isProductNotFound = false
        alternatives = nil
        isLoadingAlternatives = false
        alternativesLoadFailed = false
        savedIngredientsTextSource = nil
        pendingIngredientsScanContext = nil
        deferredHistoryLogAction = nil
    }

    /// Kullanıcı otomatik açılan OCR ekranından fotoğraf çekmeden geri döndüğünde `SearchView`
    /// tarafından çağrılır: bekleyen "ara" sonucu artık kesinleşmiş sayılır ve kaydedilir.
    func ingredientsScanDismissedWithoutCompleting() {
        pendingIngredientsScanContext = nil
        deferredHistoryLogAction?()
        deferredHistoryLogAction = nil
    }

    /// OCR ekranı ("Kontrol et") başarıyla bir sonuç ürettiğinde çağrılır: o sonuç kendi
    /// kaydını zaten yaptığından (bkz. `IngredientsScanViewModel.checkText`), bekleyen
    /// "ara" sonucunun ARTIK kaydedilmemesi gerekir — yoksa aynı tarama için iki kayıt oluşur.
    private func ingredientsScanDidProduceResult() {
        deferredHistoryLogAction = nil
    }

    /// `saved.rawText` (varsa) de taranır: ilk taramada başlık/besin tablosu dışında
    /// yakalanan bir uyarı, hafızadan ikinci kez okunurken kaçırılmasın (güvenlik
    /// gerilemesi olurdu — aynı ürün ilk okutmada "dikkat", ikincisinde "uygun" çıkamaz).
    private func computeResult(
        from saved: SavedIngredientsText,
        userAllergens: Set<Allergen>,
        customTerms: [String]
    ) -> ProductCheckResult {
        checkIngredientsTextUseCase.execute(
            rawText: saved.ingredientsText,
            userAllergens: userAllergens,
            customTerms: customTerms,
            headingFound: saved.headingFound,
            barcode: saved.barcode,
            brand: saved.brand,
            imageURL: saved.imageURL,
            categories: saved.categories,
            fullRawText: saved.rawText
        )
    }

    /// "Yeniden fotoğrafla" ile hafızadaki metin güncellendiğinde çağrılır (bkz.
    /// `makeIngredientsScanViewModel(refreshesResultOnSuccess:)`). `search()`'ün aksine
    /// tarama geçmişine YENİDEN KAYIT ATMAZ: `IngredientsScanViewModel.checkText()` bu
    /// taramanın kaydını zaten yapmıştır; burada ikinci bir kayıt oluşursa aynı tarama
    /// için geçmişte iki satır görünürdü. Sadece ekrandaki `result`/`savedIngredientsTextSource`
    /// (artık güncellenmiş metinden hesaplanarak) tazelenir.
    private func refreshResultFromMemory() {
        guard let saved = savedIngredientsTextRepository.find(barcode: barcode) else { return }
        savedIngredientsTextSource = saved
        result = computeResult(
            from: saved,
            userAllergens: profileRepository.loadAllergens(),
            customTerms: profileRepository.loadCustomTerms()
        )
    }

    private func logToHistory(product: Product, result: ProductCheckResult, source: ScanSource, rawText: String? = nil) {
        guard !result.isProfileEmpty else { return }
        scanHistoryRepository.save(ScanHistoryEntry(
            barcode: product.barcode.isEmpty ? nil : product.barcode,
            productName: product.name,
            brand: product.brand,
            imageURL: product.imageURL,
            ingredientsText: product.ingredientsText,
            rawText: rawText,
            allergens: product.allergens,
            traces: product.traces,
            categories: product.categories,
            type: product.type,
            headingFound: true,
            source: source,
            snapshotStatus: result.status
        ))
    }

    private func logNotFoundToHistory(barcode: String) {
        scanHistoryRepository.save(ScanHistoryEntry(
            barcode: barcode.isEmpty ? nil : barcode,
            productName: "Bulunamayan Ürün",
            brand: nil,
            imageURL: nil,
            ingredientsText: nil,
            allergens: [],
            traces: [],
            categories: [],
            type: .food,
            headingFound: true,
            source: .off,
            snapshotStatus: .unknown
        ))
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

    /// `context` verilirse (otomatik yönlendirme, "Yeniden oku" ya da "Yeniden fotoğrafla"),
    /// OCR ekranı barkodu ve bilinen ürün bilgisini taşır — üstte ürün adını gösterebilsin,
    /// okunan metni aynı barkodla hafızaya kaydedebilsin diye (bkz. Aşama 3, Adım C).
    ///
    /// `refreshesResultOnSuccess`: kullanıcı `SearchView`'de zaten hafızadan görüntülenen bir
    /// sonucu "Yeniden fotoğrafla" ile düzeltmeye çalışıyorsa `true` verilir. Otomatik
    /// yönlendirmenin kullandığı `pendingIngredientsScanContext`'ten TAMAMEN AYRI bir
    /// mekanizmadır: hiçbir ortak durumu paylaşmaz, bu yüzden "bir aramada en fazla bir kez"
    /// sınırını hiç etkilemez — kullanıcı "Yeniden fotoğrafla"yı istediği kadar açabilir.
    func makeIngredientsScanViewModel(
        context: IngredientsScanContext? = nil,
        refreshesResultOnSuccess: Bool = false
    ) -> IngredientsScanViewModel {
        IngredientsScanViewModel(
            textRecognitionService: textRecognitionService,
            profileRepository: profileRepository,
            savedIngredientsTextRepository: savedIngredientsTextRepository,
            scanHistoryRepository: scanHistoryRepository,
            context: context,
            onSuccessfulCheck: { [weak self] in
                self?.ingredientsScanDidProduceResult()
                if refreshesResultOnSuccess {
                    self?.refreshResultFromMemory()
                }
            }
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
