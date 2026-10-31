import Foundation

enum TextRecognitionError: Error {
    case recognitionFailed
    case noTextFound
}

/// Bir görseldeki metni cihaz üzerinde tanıyan servis. Domain katmanı Vision/UIKit
/// bilmez; implementasyon Data katmanındadır (bkz. `VisionTextRecognitionService`).
protocol TextRecognitionService {
    /// `usesLanguageCorrection`: tanınan kelimeleri dil sözlüğüne göre düzeltmeye çalışır.
    /// Türkçe için güvenilir bir sözlük olmadığından varsayılan olarak false kullanılmalıdır
    /// (bkz. çağıran taraftaki varsayılan).
    func recognizeText(in imageData: Data, usesLanguageCorrection: Bool) async throws -> String

    /// OCR için seçilen dili döndürür (geliştirme/hata ayıklama amaçlı).
    func currentRecognitionLanguage() -> String
}
