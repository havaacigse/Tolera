import Testing
@testable import Tolera

struct RecheckScanHistoryEntryUseCaseTests {
    private func makeEntry(
        source: ScanSource,
        ingredientsText: String?,
        rawText: String? = nil,
        allergens: Set<Allergen> = [],
        categories: [String] = [],
        headingFound: Bool = true
    ) -> ScanHistoryEntry {
        ScanHistoryEntry(
            barcode: "123",
            productName: "Test Ürün",
            brand: "Marka",
            imageURL: nil,
            ingredientsText: ingredientsText,
            rawText: rawText,
            allergens: allergens,
            traces: [],
            categories: categories,
            type: .food,
            headingFound: headingFound,
            source: source,
            snapshotStatus: .safe
        )
    }

    @Test("OFF kaynaklı kayıt, OFF etiketindeki alerjen güncel profille eşleşirse unsafe döner")
    func offSourcedEntryMatchesCurrentProfile() {
        let useCase = RecheckScanHistoryEntryUseCase()
        let entry = makeEntry(source: .off, ingredientsText: "su, şeker", allergens: [.milk])

        let result = useCase.execute(entry: entry, userAllergens: [.milk], customTerms: [])

        #expect(result.status == .unsafe)
    }

    @Test("Profil değiştiyse (artık o alerjen seçili değilse) aynı kayıt safe döner")
    func offSourcedEntryRecomputesWithChangedProfile() {
        let useCase = RecheckScanHistoryEntryUseCase()
        let entry = makeEntry(source: .off, ingredientsText: "su, şeker", allergens: [.milk])

        let result = useCase.execute(entry: entry, userAllergens: [.gluten], customTerms: [])

        #expect(result.status == .safe)
    }

    @Test("OCR kaynaklı kayıtta başlık bulunamamışsa temkinli kural yeniden hesaplamada da uygulanır")
    func ocrSourcedEntryWithMissingHeadingStaysUnknownEvenWithoutAllergenMatch() {
        let useCase = RecheckScanHistoryEntryUseCase()
        let entry = makeEntry(source: .ocrPhoto, ingredientsText: "su, şeker", headingFound: false)

        let result = useCase.execute(entry: entry, userAllergens: [.milk], customTerms: [])

        #expect(result.status == .unknown)
        #expect(result.isMissingIngredientsHeading)
    }

    @Test("OCR kaynaklı kayıtta başlık bulunduysa ve alerjen eşleşmediyse safe kalır")
    func ocrSourcedEntryWithHeadingFoundStaysSafe() {
        let useCase = RecheckScanHistoryEntryUseCase()
        let entry = makeEntry(source: .ocrPhoto, ingredientsText: "su, şeker", headingFound: true)

        let result = useCase.execute(entry: entry, userAllergens: [.milk], customTerms: [])

        #expect(result.status == .safe)
    }

    @Test("OCR kaynaklı kayıtta kaydedilmiş kategori bilgisi Product'a taşınır")
    func ocrSourcedEntryKeepsCategoriesForAlternatives() {
        let useCase = RecheckScanHistoryEntryUseCase()
        let entry = makeEntry(source: .ocrPhoto, ingredientsText: "su, şeker", categories: ["yogurts"], headingFound: true)

        let result = useCase.execute(entry: entry, userAllergens: [.milk], customTerms: [])

        #expect(result.product.categories == ["yogurts"])
    }

    /// Güvenlik gerilemesi testi: kaydın `rawText`'inde başlık/besin tablosu dışında
    /// yakalanan bir uyarı varsa, geçmişten yeniden hesaplanırken de kaçırılmamalı.
    @Test("rawText'te 'Fındık içerebilir' varsa, geçmişten yeniden hesaplamada fındık mayContain olur")
    func ocrSourcedEntryRawTextTriggersWarningSentenceRescan() {
        let useCase = RecheckScanHistoryEntryUseCase()
        let entry = makeEntry(
            source: .ocrPhoto,
            ingredientsText: "şeker, kakao",
            rawText: "İçindekiler: şeker, kakao. Besin değerleri: Enerji 500 kcal. Alerjen uyarısı: Fındık içerebilir.",
            headingFound: true
        )

        let result = useCase.execute(entry: entry, userAllergens: [.nuts], customTerms: [])

        #expect(result.status == .caution)
        #expect(result.matchedTraces.contains(.nuts))
    }
}
