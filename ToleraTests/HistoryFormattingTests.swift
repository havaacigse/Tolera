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
}
