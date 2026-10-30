import Testing
@testable import Tolera

struct CustomTermDetectorTests {
    private let detector = CustomTermDetector()

    @Test("çilek terimi içindekiler metninde eşleşir")
    func strawberryTermMatches() {
        let result = detector.detect(customTerms: ["çilek"], in: "çilek aroması, şeker")
        #expect(result == ["çilek"])
    }

    @Test("büyük harfli terim küçük harfli metinle eşleşir")
    func uppercaseTermMatchesLowercaseText() {
        let result = detector.detect(customTerms: ["ÇİLEK"], in: "çilek aroması")
        #expect(result == ["çilek"])
    }

    @Test("\"çilekli\" kelime başı eşleşmesiyle yakalanır")
    func wordStartMatchCatchesInflectedForm() {
        let result = detector.detect(customTerms: ["çilek"], in: "çilekli yoğurt")
        #expect(result == ["çilek"])
    }

    @Test("eşleşmeyen terim sonuçta yer almaz")
    func nonMatchingTermIsExcluded() {
        let result = detector.detect(customTerms: ["domates"], in: "çilek aroması, şeker")
        #expect(result.isEmpty)
    }

    @Test("boş içindekiler metninde hiçbir terim eşleşmez")
    func emptyIngredientsTextYieldsNoMatches() {
        let result = detector.detect(customTerms: ["çilek"], in: "")
        #expect(result.isEmpty)
    }
}
