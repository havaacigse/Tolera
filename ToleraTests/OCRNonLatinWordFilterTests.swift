import Testing
@testable import Tolera

struct OCRNonLatinWordFilterTests {
    @Test func satirdakiArapcaKelimeAtilirTurkceKisimKalir() {
        let result = OCRNonLatinWordFilter.removeNonLatinWords(from: "Buğday unu / دقيق القمح, şeker")
        #expect(result == "Buğday unu / şeker")
    }

    /// Filtrelenmiş metin, tanıdığı kelimeyi kaybetmediği için dedektörde gluten
    /// bulunmaya devam eder (asıl istenen davranış: yan yana gelen yabancı dil
    /// kelimesi Türkçe kısmın analizini bozmasın).
    @Test func filtrelenmisMetindeGlutenBulunur() {
        let filtered = OCRNonLatinWordFilter.removeNonLatinWords(from: "Buğday unu / دقيق القمح, şeker")
        let detection = IngredientAllergenDetector().detect(in: filtered)
        #expect(detection.contains.contains(.gluten))
    }

    @Test func satirSonlariKorunur() {
        let result = OCRNonLatinWordFilter.removeNonLatinWords(from: "şeker\nمرحبا\nsu")
        #expect(result == "şeker\n\nsu")
    }

    @Test func sadeceLatinMetinDegismez() {
        let result = OCRNonLatinWordFilter.removeNonLatinWords(from: "şeker, su, buğday unu")
        #expect(result == "şeker, su, buğday unu")
    }
}
