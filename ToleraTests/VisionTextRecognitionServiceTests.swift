import Testing
@testable import Tolera

struct VisionTextRecognitionServiceTests {
    @Test func trTrDesteklenirseOnuSecer() {
        let result = VisionTextRecognitionService.preferredRecognitionLanguage(supported: ["tr-TR", "en-US"])
        #expect(result == "tr-TR")
    }

    @Test func trTrDesteklenmezseEnUsSecer() {
        let result = VisionTextRecognitionService.preferredRecognitionLanguage(supported: ["en-US", "de-DE"])
        #expect(result == "en-US")
    }

    @Test func destekListesiBossaEnUsSecer() {
        let result = VisionTextRecognitionService.preferredRecognitionLanguage(supported: [])
        #expect(result == "en-US")
    }
}
