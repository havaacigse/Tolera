import Foundation
import Testing
@testable import Tolera

struct IngredientsScanRedirectPolicyTests {
    private func makeResult(
        ingredientsText: String?,
        status: CheckStatus,
        isCosmeticNotSupported: Bool = false,
        isProfileEmpty: Bool = false
    ) -> ProductCheckResult {
        let product = Product(
            barcode: "123",
            name: "Test Ürün",
            brand: nil,
            imageURL: nil,
            ingredientsText: ingredientsText,
            allergens: [],
            traces: [],
            categories: [],
            type: isCosmeticNotSupported ? .cosmetic : .food
        )
        return ProductCheckResult(
            product: product,
            status: status,
            matchedAllergens: [],
            matchedTraces: [],
            detectedFromIngredients: [],
            matchedCustomTerms: [],
            isCosmeticNotSupported: isCosmeticNotSupported,
            isProfileEmpty: isProfileEmpty,
            isMissingIngredientsHeading: false,
            allergenReasons: [:]
        )
    }

    @Test("Ürün OFF'ta hiç bulunamadıysa yönlendirilir")
    func productNotFoundRedirects() {
        let shouldRedirect = IngredientsScanRedirectPolicy.shouldRedirectToIngredientsScan(
            isProductNotFound: true,
            result: nil,
            isProfileEmpty: false
        )
        #expect(shouldRedirect)
    }

    @Test("Ürün bulunamadı ama profil de boşsa yönlendirilmez (önce profil uyarısı)")
    func productNotFoundWithEmptyProfileDoesNotRedirect() {
        let shouldRedirect = IngredientsScanRedirectPolicy.shouldRedirectToIngredientsScan(
            isProductNotFound: true,
            result: nil,
            isProfileEmpty: true
        )
        #expect(!shouldRedirect)
    }

    @Test("Ürün bulundu ama içindekiler metni boşsa yönlendirilir")
    func missingIngredientsTextRedirects() {
        let result = makeResult(ingredientsText: nil, status: .unknown)
        let shouldRedirect = IngredientsScanRedirectPolicy.shouldRedirectToIngredientsScan(
            isProductNotFound: false,
            result: result,
            isProfileEmpty: false
        )
        #expect(shouldRedirect)
    }

    @Test("Metin var ama dil anlaşılamadığı için unknown dönerse yönlendirilir")
    func unrecognizedLanguageUnknownRedirects() {
        let result = makeResult(ingredientsText: "Weizenmehl, Zucker", status: .unknown)
        let shouldRedirect = IngredientsScanRedirectPolicy.shouldRedirectToIngredientsScan(
            isProductNotFound: false,
            result: result,
            isProfileEmpty: false
        )
        #expect(shouldRedirect)
    }

    @Test("Kozmetik ürünse, metin olmasa da yönlendirilmez")
    func cosmeticProductDoesNotRedirect() {
        let result = makeResult(ingredientsText: nil, status: .unknown, isCosmeticNotSupported: true)
        let shouldRedirect = IngredientsScanRedirectPolicy.shouldRedirectToIngredientsScan(
            isProductNotFound: false,
            result: result,
            isProfileEmpty: false
        )
        #expect(!shouldRedirect)
    }

    @Test("Profil boşsa, metin olmasa da yönlendirilmez")
    func emptyProfileDoesNotRedirect() {
        let result = makeResult(ingredientsText: nil, status: .unknown, isProfileEmpty: true)
        let shouldRedirect = IngredientsScanRedirectPolicy.shouldRedirectToIngredientsScan(
            isProductNotFound: false,
            result: result,
            isProfileEmpty: true
        )
        #expect(!shouldRedirect)
    }

    @Test("Metin var, dil de anlaşıldı ve safe/unsafe/caution ise yönlendirilmez")
    func normalResultsDoNotRedirect() {
        for status: CheckStatus in [.safe, .unsafe, .caution] {
            let result = makeResult(ingredientsText: "su, şeker", status: status)
            let shouldRedirect = IngredientsScanRedirectPolicy.shouldRedirectToIngredientsScan(
                isProductNotFound: false,
                result: result,
                isProfileEmpty: false
            )
            #expect(!shouldRedirect)
        }
    }
}
