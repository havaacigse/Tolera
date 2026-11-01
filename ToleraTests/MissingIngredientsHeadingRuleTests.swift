import Testing
@testable import Tolera

struct MissingIngredientsHeadingRuleTests {
    private func makeResult(status: CheckStatus, isMissingIngredientsHeading: Bool = false) -> ProductCheckResult {
        let product = Product(
            barcode: "123",
            name: "Test Ürün",
            brand: nil,
            imageURL: nil,
            ingredientsText: "su, şeker",
            allergens: [],
            traces: [],
            categories: [],
            type: .food
        )
        return ProductCheckResult(
            product: product,
            status: status,
            matchedAllergens: status == .unsafe ? [.milk] : [],
            matchedTraces: status == .caution ? [.milk] : [],
            detectedFromIngredients: [],
            matchedCustomTerms: [],
            isCosmeticNotSupported: false,
            isProfileEmpty: false,
            isMissingIngredientsHeading: isMissingIngredientsHeading,
            allergenReasons: [:]
        )
    }

    @Test("Başlık bulunamadıysa ve sonuç safe ise unknown'a çevrilir")
    func missingHeadingWithSafeStatusBecomesUnknown() {
        let result = makeResult(status: .safe)

        let ruled = MissingIngredientsHeadingRule.apply(to: result, headingFound: false)

        #expect(ruled.status == .unknown)
        #expect(ruled.isMissingIngredientsHeading)
    }

    @Test("Başlık bulunamadı ama alerjen eşleştiyse (unsafe) sonuç değişmez")
    func missingHeadingWithUnsafeStatusStaysUnsafe() {
        let result = makeResult(status: .unsafe)

        let ruled = MissingIngredientsHeadingRule.apply(to: result, headingFound: false)

        #expect(ruled.status == .unsafe)
        #expect(!ruled.isMissingIngredientsHeading)
    }

    @Test("Başlık bulunamadı ama eser miktar (caution) eşleştiyse sonuç değişmez")
    func missingHeadingWithCautionStatusStaysCaution() {
        let result = makeResult(status: .caution)

        let ruled = MissingIngredientsHeadingRule.apply(to: result, headingFound: false)

        #expect(ruled.status == .caution)
        #expect(!ruled.isMissingIngredientsHeading)
    }

    @Test("Başlık bulunduysa ve sonuç safe ise değişmez")
    func headingFoundWithSafeStatusStaysSafe() {
        let result = makeResult(status: .safe)

        let ruled = MissingIngredientsHeadingRule.apply(to: result, headingFound: true)

        #expect(ruled.status == .safe)
        #expect(!ruled.isMissingIngredientsHeading)
    }
}
