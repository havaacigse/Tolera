import Foundation
import Testing
@testable import Tolera

/// `HistoryView`'ın kullandığı saf biçimlendirme fonksiyonları (`HistoryFormatting`).
/// View'ın kendisi test edilmiyor; sadece View'ın çağırdığı bu metin üretimi testli.
struct HistoryFormattingTests {
    private func makeEntry(
        productName: String = "Test Ürün",
        barcode: String? = "123",
        source: ScanSource = .off,
        scannedAt: Date = Date()
    ) -> ScanHistoryEntry {
        ScanHistoryEntry(
            barcode: barcode,
            productName: productName,
            brand: nil,
            imageURL: nil,
            ingredientsText: "su, şeker",
            allergens: [],
            traces: [],
            categories: [],
            type: .food,
            headingFound: true,
            source: source,
            snapshotStatus: .safe,
            scannedAt: scannedAt
        )
    }

    // MARK: - Gün başlığı

    @Test("Bugünün gün başlığı 'Bugün' olur")
    func todayHeaderIsBugun() {
        let now = Date()
        #expect(HistoryFormatting.dayHeaderText(for: now, now: now) == "Bugün")
    }

    @Test("Dünün gün başlığı 'Dün' olur")
    func yesterdayHeaderIsDun() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        #expect(HistoryFormatting.dayHeaderText(for: yesterday, now: now) == "Dün")
    }

    @Test("İki gün önceki başlık 'Bugün' ya da 'Dün' değildir")
    func olderDayHeaderIsNeitherTodayNorYesterday() {
        let now = Date()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let header = HistoryFormatting.dayHeaderText(for: twoDaysAgo, now: now)
        #expect(header != "Bugün")
        #expect(header != "Dün")
    }

    // MARK: - Durum etiketi

    @Test("Durum etiketleri her CheckStatus için doğru Türkçe metni döner")
    func statusLabelsAreCorrect() {
        #expect(HistoryFormatting.statusLabelText(for: .unsafe) == "Uygun değil")
        #expect(HistoryFormatting.statusLabelText(for: .caution) == "Dikkat")
        #expect(HistoryFormatting.statusLabelText(for: .safe) == "Uygun")
        #expect(HistoryFormatting.statusLabelText(for: .unknown) == "Bilinmiyor")
    }

    // MARK: - Kaynak metni

    @Test("Kaynak metinleri doğru döner: .off → Barkod, .ocrPhoto → Fotoğraf")
    func sourceTextsAreCorrect() {
        #expect(HistoryFormatting.sourceText(for: .off) == "Barkod")
        #expect(HistoryFormatting.sourceText(for: .ocrPhoto) == "Fotoğraf")
    }

    // MARK: - Görünen ürün adı: ürün adı → barkod → "Adsız ürün"

    @Test("Ürün adı doluysa doğrudan o gösterilir")
    func displayNameUsesProductNameWhenPresent() {
        let entry = makeEntry(productName: "Yoğurt", barcode: "123")
        #expect(HistoryFormatting.displayName(for: entry) == "Yoğurt")
    }

    @Test("Ürün adı boşsa ve barkod varsa barkod gösterilir")
    func displayNameFallsBackToBarcodeWhenNameEmpty() {
        let entry = makeEntry(productName: "", barcode: "8680181000017")
        #expect(HistoryFormatting.displayName(for: entry) == "8680181000017")
    }

    @Test("Ürün adı ve barkod boşsa/yoksa 'Adsız ürün' gösterilir")
    func displayNameFallsBackToPlaceholderWhenNameAndBarcodeMissing() {
        let entry = makeEntry(productName: "", barcode: nil)
        #expect(HistoryFormatting.displayName(for: entry) == "Adsız ürün")
    }

    // MARK: - HistoryDetailView için gerekçe/neden yardımcıları

    private func makeProduct(ingredientsText: String? = "süt tozu, şeker") -> Product {
        Product(
            barcode: "123",
            name: "Test Ürün",
            brand: "Marka",
            imageURL: nil,
            ingredientsText: ingredientsText,
            allergens: [],
            traces: [],
            categories: [],
            type: .food
        )
    }

    private func makeResult(
        ingredientsText: String? = "süt tozu, şeker",
        status: CheckStatus,
        matchedAllergens: Set<Allergen> = [],
        matchedTraces: Set<Allergen> = [],
        matchedCustomTerms: [String] = [],
        isCosmeticNotSupported: Bool = false,
        isProfileEmpty: Bool = false,
        isMissingIngredientsHeading: Bool = false,
        allergenReasons: [Allergen: String] = [:]
    ) -> ProductCheckResult {
        ProductCheckResult(
            product: makeProduct(ingredientsText: ingredientsText),
            status: status,
            matchedAllergens: matchedAllergens,
            matchedTraces: matchedTraces,
            detectedFromIngredients: [],
            matchedCustomTerms: matchedCustomTerms,
            isCosmeticNotSupported: isCosmeticNotSupported,
            isProfileEmpty: isProfileEmpty,
            isMissingIngredientsHeading: isMissingIngredientsHeading,
            allergenReasons: allergenReasons
        )
    }

    @Test("Süt eşleşmesi: matchedAllergens içindeki süt için allergenReasons'taki gerekçe aynen döner")
    func matchedAllergenReasonsIncludesMilkWithItsReason() {
        let result = makeResult(
            status: .unsafe,
            matchedAllergens: [.milk],
            allergenReasons: [.milk: "Etiketin başka bir yerinde: Alerjen uyarısı: Süt içerir."]
        )

        let reasons = HistoryFormatting.matchedAllergenReasons(for: result)

        #expect(reasons.count == 1)
        #expect(reasons.first?.allergen == .milk)
        #expect(reasons.first?.reason == "Etiketin başka bir yerinde: Alerjen uyarısı: Süt içerir.")
    }

    @Test("İz (mayContain) eşleşmesi: matchedTraces içindeki alerjen için gerekçe döner")
    func matchedTraceReasonsIncludesTraceAllergenWithItsReason() {
        let result = makeResult(
            status: .caution,
            matchedTraces: [.nuts],
            allergenReasons: [.nuts: "Open Food Facts etiketi"]
        )

        let reasons = HistoryFormatting.matchedTraceReasons(for: result)

        #expect(reasons.count == 1)
        #expect(reasons.first?.allergen == .nuts)
        #expect(reasons.first?.reason == "Open Food Facts etiketi")
    }

    @Test("Hiç eşleşme yokken alerjen ve iz gerekçe listeleri boş döner")
    func noMatchesProduceEmptyReasonLists() {
        let result = makeResult(status: .safe)

        #expect(HistoryFormatting.matchedAllergenReasons(for: result).isEmpty)
        #expect(HistoryFormatting.matchedTraceReasons(for: result).isEmpty)
    }

    @Test("Durum .unknown değilse unknownReasonText nil döner")
    func unknownReasonTextIsNilWhenStatusIsNotUnknown() {
        let result = makeResult(status: .safe)
        #expect(HistoryFormatting.unknownReasonText(for: result) == nil)
    }

    @Test("Kozmetik ürün desteklenmiyorsa nedeni açıkça belirtir")
    func unknownReasonTextExplainsCosmeticNotSupported() {
        let result = makeResult(status: .unknown, isCosmeticNotSupported: true)
        #expect(HistoryFormatting.unknownReasonText(for: result) == "Kozmetik ürünler için alerjen analizi şu an desteklenmiyor.")
    }

    @Test("Profil boşsa nedeni açıkça belirtir")
    func unknownReasonTextExplainsEmptyProfile() {
        let result = makeResult(status: .unknown, isProfileEmpty: true)
        #expect(HistoryFormatting.unknownReasonText(for: result) == "Profilinde hiç alerjen veya özel terim seçili değil.")
    }

    @Test("İçindekiler başlığı bulunamadıysa nedeni açıkça belirtir")
    func unknownReasonTextExplainsMissingIngredientsHeading() {
        let result = makeResult(status: .unknown, isMissingIngredientsHeading: true)
        #expect(HistoryFormatting.unknownReasonText(for: result) == "İçindekiler başlığı metinde bulunamadı, bu yüzden sonuç güvenilir sayılmadı.")
    }

    @Test("İçindekiler metni yoksa nedeni açıkça belirtir")
    func unknownReasonTextExplainsMissingIngredientsText() {
        let result = makeResult(ingredientsText: nil, status: .unknown)
        #expect(HistoryFormatting.unknownReasonText(for: result) == "Bu ürün için içindekiler bilgisi yok.")
    }

    @Test("İçindekiler metni var ama hiçbir bayrak set değilse (desteklenmeyen dil ihtimali) nedeni açıkça belirtir")
    func unknownReasonTextExplainsUnrecognizedTextAsLastResort() {
        let result = makeResult(ingredientsText: "some unrecognized text", status: .unknown)
        #expect(HistoryFormatting.unknownReasonText(for: result) == "İçindekiler metni anlaşılamadı (desteklenmeyen bir dilde olabilir).")
    }
}
