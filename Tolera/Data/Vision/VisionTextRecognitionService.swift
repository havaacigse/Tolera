import UIKit
import Vision

/// `TextRecognitionService`'in Vision framework ile cihaz üzerinde çalışan implementasyonu.
/// Hiçbir ağ isteği yapmaz; tüm tanıma cihazda gerçekleşir.
final class VisionTextRecognitionService: TextRecognitionService {
    private static let preferredLanguage = "tr-TR"
    private static let fallbackLanguage = "en-US"
    private static let recognitionLevel: VNRequestTextRecognitionLevel = .accurate

    func recognizeText(in imageData: Data, usesLanguageCorrection: Bool) async throws -> String {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw TextRecognitionError.recognitionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if error != nil {
                    continuation.resume(throwing: TextRecognitionError.recognitionFailed)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: TextRecognitionError.recognitionFailed)
                    return
                }

                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                guard !lines.isEmpty else {
                    continuation.resume(throwing: TextRecognitionError.noTextFound)
                    return
                }

                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = Self.recognitionLevel
            request.usesLanguageCorrection = usesLanguageCorrection
            request.recognitionLanguages = [Self.selectedRecognitionLanguage(for: request)]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: TextRecognitionError.recognitionFailed)
            }
        }
    }

    /// Geliştirme/hata ayıklama amaçlı: gerçek bir tanıma yapmadan OCR için seçilecek dili döndürür.
    func currentRecognitionLanguage() -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = Self.recognitionLevel
        return Self.selectedRecognitionLanguage(for: request)
    }

    private static func selectedRecognitionLanguage(for request: VNRecognizeTextRequest) -> String {
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        return preferredRecognitionLanguage(supported: supported)
    }

    /// tr-TR destekleniyorsa onu, değilse en-US'i seçer. Vision şu an (iOS 18) tr-TR
    /// desteklemiyor (gerçek bir istekle doğrulandı); bu fonksiyon saf olduğundan
    /// Vision'a ihtiyaç duymadan sahte desteklenen-dil listeleriyle test edilebilir.
    static func preferredRecognitionLanguage(supported: [String]) -> String {
        supported.contains(preferredLanguage) ? preferredLanguage : fallbackLanguage
    }
}
