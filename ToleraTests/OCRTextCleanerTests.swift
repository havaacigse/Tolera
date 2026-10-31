import Testing
@testable import Tolera

struct OCRTextCleanerTests {
    @Test func tireIleBolunenKelimeBirlesir() {
        let result = OCRTextCleaner.clean("buğ-\nday unu")
        #expect(result == "buğday unu")
    }

    @Test func satirSonuBosluğaCevrilir() {
        let result = OCRTextCleaner.clean("şeker\nsu\ntuz")
        #expect(result == "şeker su tuz")
    }

    @Test func tireVeBosluklaBirlikteSatirSonuBirlesir() {
        let result = OCRTextCleaner.clean("fın-  \n  dık")
        #expect(result == "fındık")
    }

    @Test func fazlaBosluklarSikistirilir() {
        let result = OCRTextCleaner.clean("şeker,   su")
        #expect(result == "şeker, su")
    }

    @Test func basVeSondakiBosluklarKirpilir() {
        let result = OCRTextCleaner.clean("  şeker, su  \n")
        #expect(result == "şeker, su")
    }
}
