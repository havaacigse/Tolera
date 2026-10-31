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

    init(
        textRecognitionService: TextRecognitionService,
        checkIngredientsTextUseCase: CheckIngredientsTextUseCase = CheckIngredientsTextUseCase(),
        profileRepository: UserProfileRepository
    ) {
        self.textRecognitionService = textRecognitionService
        self.checkIngredientsTextUseCase = checkIngredientsTextUseCase
        self.profileRepository = profileRepository
    }

    func recognizeText(from imageData: Data) {
        isRecognizing = true
        recognitionError = nil
        result = nil
        extractedText = ""
        fullRecognizedText = ""
        isShowingFullText = false

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
            customTerms: customTerms
        )
    }

    func reset() {
        extractedText = ""
        fullRecognizedText = ""
        isShowingFullText = false
        recognitionError = nil
        result = nil
    }
}
