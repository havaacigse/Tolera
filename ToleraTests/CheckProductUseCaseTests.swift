import Testing
@testable import Tolera

struct CheckProductUseCaseTests {
    private func makeProduct(
        allergens: Set<Allergen> = [],
        traces: Set<Allergen> = [],
        ingredientsText: String? = "su, şeker"
    ) -> Product {
        Product(
            barcode: "0000000000000",
            name: "Test Ürünü",
            brand: "Test Marka",
            imageURL: nil,
            ingredientsText: ingredientsText,
            allergens: allergens,
            traces: traces,
            categories: [],
            type: .food
        )
    }

    @Test func sütAlerjisiVeSütİcerenÜrünUnsafeDöner() {
        let product = makeProduct(allergens: [.milk])
        let result = CheckProductUseCase().execute(product: product, userAllergens: [.milk])

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens == [.milk])
    }

    @Test func fındıkAlerjisiVeEserMiktarFındıkCautionDöner() {
        let product = makeProduct(traces: [.nuts])
        let result = CheckProductUseCase().execute(product: product, userAllergens: [.nuts])

        #expect(result.status == .caution)
        #expect(result.matchedTraces == [.nuts])
    }

    @Test func aynıAlerjenHemAllergensHemTracesteSadeceMatchedAllergensteOlur() {
        let product = makeProduct(allergens: [.milk], traces: [.milk])
        let result = CheckProductUseCase().execute(product: product, userAllergens: [.milk])

        #expect(result.matchedAllergens == [.milk])
        #expect(result.matchedTraces.isEmpty)
    }

    @Test func glutenAlerjisiVeSadeceSütİcerenÜrünSafeDöner() {
        let product = makeProduct(allergens: [.milk], ingredientsText: "süt")
        let result = CheckProductUseCase().execute(product: product, userAllergens: [.gluten])

        #expect(result.status == .safe)
        #expect(result.matchedAllergens.isEmpty)
        #expect(result.matchedTraces.isEmpty)
    }

    @Test func alerjenBilgisiBosVeIcindekilerNilUnknownDöner() {
        let product = makeProduct(ingredientsText: nil)
        let result = CheckProductUseCase().execute(product: product, userAllergens: [.milk])

        #expect(result.status == .unknown)
    }

    @Test func alerjenBilgisiBosVeIcindekilerBosStringUnknownDöner() {
        let product = makeProduct(ingredientsText: "")
        let result = CheckProductUseCase().execute(product: product, userAllergens: [.milk])

        #expect(result.status == .unknown)
    }

    @Test func birdenFazlaAlerjenVarsaHepsiMatchedAllergensteOlur() {
        let product = makeProduct(allergens: [.milk, .gluten])
        let result = CheckProductUseCase().execute(product: product, userAllergens: [.milk, .gluten])

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens == [.milk, .gluten])
    }

    @Test func icerikMetnindenTespitEdilenAlerjenMatchedAllergensteOlur() {
        let product = makeProduct(ingredientsText: "buğday unu, su")
        let result = CheckProductUseCase().execute(product: product, userAllergens: [.gluten])

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens == [.gluten])
        #expect(result.detectedFromIngredients == [.gluten])
    }

    @Test func offEtiketiVeIcerikTespitiBirlesir() {
        let product = makeProduct(allergens: [.milk], ingredientsText: "buğday unu")
        let result = CheckProductUseCase().execute(product: product, userAllergens: [.milk, .gluten])

        #expect(result.matchedAllergens == [.milk, .gluten])
        #expect(result.detectedFromIngredients == [.gluten])
    }

    @Test func detectedFromIngredientsOffEtiketindekiAlerjeniTekrarIcermez() {
        let product = makeProduct(allergens: [.milk], ingredientsText: "süt, buğday unu")
        let result = CheckProductUseCase().execute(product: product, userAllergens: [.milk, .gluten])

        #expect(result.detectedFromIngredients == [.gluten])
        #expect(result.matchedAllergens == [.milk, .gluten])
    }
}
