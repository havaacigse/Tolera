import Foundation
import Observation

@Observable
final class IngredientsScanViewModel {
    var isRecognizing = false
    var extractedText = ""
    var fullRecognizedText = ""
    var isShowingFullText = false
    var recognitionError: String?
    var result: ProductCheckResult?
    /// "İçindekiler" başlığı metinde bulunamadıysa true; kontrol ekranında kullanıcıyı
    /// önceden uyarmak için kullanılır. Henüz bir metin okunmadıysa varsayılan true'dur
    /// (uyarı gösterilmez).
    var hasIngredientsHeading = true

    #if DEBUG
    /// Sadece DEBUG build'de görünen bir anahtarla kontrol edilir; varsayılan false'tur
    /// çünkü Vision'ın dil düzeltmesi Türkçe kelimeleri İngilizce sözlüğe göre bozabilir.
    var isLanguageCorrectionEnabled = false

    var debugSelectedLanguage: String {
        textRecognitionService.currentRecognitionLanguage()
    }
    #endif

    private let textRecognitionService: TextRecognitionService
    private let checkIngredientsTextUseCase: CheckIngredientsTextUseCase
    private let profileRepository: UserProfileRepository
    private let savedIngredientsTextRepository: SavedIngredientsTextRepository
    private let scanHistoryRepository: ScanHistoryRepository
    /// Barkod taramasından yönlendirildiyse (otomatik ya da "Yeniden oku" ile) biliniyor;
    /// doğrudan "Fotoğrafla" butonuyla açılan akışta nil'dir.
    private let context: IngredientsScanContext?
    /// Bu ekran barkod taramasından (otomatik yönlendirme) açıldıysa, `checkText()` bir
    /// sonuç ürettiğinde çağrılan geri bildirim — çağıran taraf (bkz. `SearchViewModel`)
    /// kendi bekleyen "ara" sonucunu artık kaydetmemesi gerektiğini böyle öğrenir.
    private let onSuccessfulCheck: (() -> Void)?

    /// `IngredientsScanView` üstte göstersin diye; bağlam yoksa (doğrudan "Fotoğrafla") nil'dir.
    var productName: String? { context?.productName }

    init(
        textRecognitionService: TextRecognitionService,
        checkIngredientsTextUseCase: CheckIngredientsTextUseCase = CheckIngredientsTextUseCase(),
        profileRepository: UserProfileRepository,
        savedIngredientsTextRepository: SavedIngredientsTextRepository,
        scanHistoryRepository: ScanHistoryRepository,
        context: IngredientsScanContext? = nil,
        onSuccessfulCheck: (() -> Void)? = nil
    ) {
        self.textRecognitionService = textRecognitionService
        self.checkIngredientsTextUseCase = checkIngredientsTextUseCase
        self.profileRepository = profileRepository
        self.savedIngredientsTextRepository = savedIngredientsTextRepository
        self.scanHistoryRepository = scanHistoryRepository
        self.context = context
        self.onSuccessfulCheck = onSuccessfulCheck
    }

    func recognizeText(from imageData: Data) {
        isRecognizing = true
        recognitionError = nil
        result = nil
        extractedText = ""
        fullRecognizedText = ""
        isShowingFullText = false
        hasIngredientsHeading = true

        Task {
            #if DEBUG
            let useLanguageCorrection = isLanguageCorrectionEnabled
            #else
            let useLanguageCorrection = false
            #endif

            do {
                let rawText = try await textRecognitionService.recognizeText(
                    in: imageData,
                    usesLanguageCorrection: useLanguageCorrection
                )
                // Filtre düzenleme ekranına GELMEDEN önce uygulanır: kullanıcı TextEditor'da
                // tam olarak analiz edilecek metni görsün. "Tüm metni göster" ham OCR
                // metnini (fullRecognizedText) değişmeden gösterir.
                fullRecognizedText = rawText
                let latinOnlyText = OCRNonLatinWordFilter.removeNonLatinWords(from: rawText)
                hasIngredientsHeading = IngredientsSectionExtractor.headingFound(in: latinOnlyText)
                extractedText = IngredientsSectionExtractor.extract(from: latinOnlyText)
            } catch {
                recognitionError = "Metin okunamadı. Daha net bir fotoğraf dene."
            }
            isRecognizing = false
        }
    }

    func checkText() {
        let textToAnalyze = isShowingFullText ? fullRecognizedText : extractedText
        let userAllergens = profileRepository.loadAllergens()
        let customTerms = profileRepository.loadCustomTerms()
        result = checkIngredientsTextUseCase.execute(
            rawText: textToAnalyze,
            userAllergens: userAllergens,
            customTerms: customTerms,
            headingFound: hasIngredientsHeading,
            barcode: context?.barcode ?? "",
            brand: context?.brand,
            imageURL: context?.imageURL,
            categories: context?.categories ?? []
        )

        // Barkod biliniyorsa (barkod taramasından yönlendirildiyse) bu metin barkod
        // hafızasına kaydedilir; aynı barkod bir dahaki sefer OFF'a gitmeden bu metinle
        // kontrol edilebilsin. Barkod yoksa (doğrudan "Fotoğrafla") kaydedilecek yer yok.
        if let barcode = context?.barcode, !barcode.isEmpty {
            savedIngredientsTextRepository.save(
                SavedIngredientsText(
                    barcode: barcode,
                    productName: context?.productName,
                    brand: context?.brand,
                    imageURL: context?.imageURL,
                    categories: context?.categories ?? [],
                    ingredientsText: textToAnalyze,
                    headingFound: hasIngredientsHeading,
                    savedAt: Date()
                )
            )
        }

        // Bu, bu taramanın SON sonucudur; bekleyen bir "ara" kayıt varsa (bkz.
        // SearchViewModel.deferredHistoryLogAction) artık gereksizdir.
        onSuccessfulCheck?()

        guard let result, !result.isProfileEmpty else { return }
        scanHistoryRepository.save(ScanHistoryEntry(
            barcode: (context?.barcode).flatMap { $0.isEmpty ? nil : $0 },
            productName: context?.productName ?? result.product.name,
            brand: context?.brand,
            imageURL: context?.imageURL,
            ingredientsText: result.product.ingredientsText,
            allergens: [],
            traces: [],
            categories: context?.categories ?? [],
            type: .food,
            headingFound: hasIngredientsHeading,
            source: .ocrPhoto,
            snapshotStatus: result.status
        ))
    }

    func reset() {
        extractedText = ""
        fullRecognizedText = ""
        isShowingFullText = false
        hasIngredientsHeading = true
        recognitionError = nil
        result = nil
    }
}
