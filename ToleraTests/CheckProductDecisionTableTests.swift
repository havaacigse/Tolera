import Testing
@testable import Tolera

/// `CheckProductUseCase` + `MissingIngredientsHeadingRule` zincirinin tüm girdi
/// kombinasyonlarında dokümante edilmiş kurala uyduğunu doğrulayan karar tablosu testi.
/// Beklenen sonuç, üretim kodundan BAĞIMSIZ olarak `expectedResult`te yeniden yazılır;
/// böylece ikisi arasındaki her fark gerçek bir regresyon ya da kural kaymasıdır.
struct CheckProductDecisionTableTests {
    private enum ProfileState: String, CaseIterable { case empty, full }
    private enum TextPresence: String, CaseIterable { case none, empty, full }
    private enum TextAllergenState: String, CaseIterable { case content, trace, absent }
    private enum LanguageState: String, CaseIterable { case recognized, unrecognized }
    private enum HeadingState: String, CaseIterable { case found, notFound }
    private enum OffTagState: String, CaseIterable { case present, absent }
    private enum CustomTermState: String, CaseIterable { case matched, notMatched }
    private enum ProductTypeState: String, CaseIterable { case food, cosmetic }

    private struct Scenario: Sendable, CustomTestStringConvertible {
        let profile: ProfileState
        let textPresence: TextPresence
        let textAllergen: TextAllergenState
        let language: LanguageState
        let heading: HeadingState
        let offTag: OffTagState
        let customTerm: CustomTermState
        let productType: ProductTypeState

        var testDescription: String {
            "profil=\(profile.rawValue) metin=\(textPresence.rawValue) alerjen=\(textAllergen.rawValue) " +
            "dil=\(language.rawValue) baslik=\(heading.rawValue) off=\(offTag.rawValue) " +
            "ozelTerim=\(customTerm.rawValue) tip=\(productType.rawValue)"
        }
    }

    private struct ExpectedOutcome: Equatable {
        let status: CheckStatus
        let isProfileEmpty: Bool
        let isCosmeticNotSupported: Bool
        let isMissingIngredientsHeading: Bool
    }

    /// Hedef alerjen her senaryoda sabit olarak süt (.milk) kullanılır; dikkat edilen tek
    /// alerjen olduğundan kombinasyon sayısı yönetilebilir kalır ama tüm dallar yine de gezilir.
    private static let targetAllergen: Allergen = .milk
    private static let customTermWord = "çilek"

    private static func allScenarios() -> [Scenario] {
        var scenarios: [Scenario] = []
        for profile in ProfileState.allCases {
            for heading in HeadingState.allCases {
                for offTag in OffTagState.allCases {
                    for productType in ProductTypeState.allCases {
                        for textPresence in TextPresence.allCases {
                            if textPresence == .full {
                                for textAllergen in TextAllergenState.allCases {
                                    for language in LanguageState.allCases {
                                        for customTerm in CustomTermState.allCases {
                                            scenarios.append(Scenario(
                                                profile: profile, textPresence: textPresence,
                                                textAllergen: textAllergen, language: language,
                                                heading: heading, offTag: offTag,
                                                customTerm: customTerm, productType: productType
                                            ))
                                        }
                                    }
                                }
                            } else {
                                scenarios.append(Scenario(
                                    profile: profile, textPresence: textPresence,
                                    textAllergen: .absent, language: .recognized,
                                    heading: heading, offTag: offTag,
                                    customTerm: .notMatched, productType: productType
                                ))
                            }
                        }
                    }
                }
            }
        }
        return scenarios
    }

    private static func makeIngredientsText(_ scenario: Scenario) -> String? {
        switch scenario.textPresence {
        case .none: return nil
        case .empty: return ""
        case .full:
            let customTermSuffix = scenario.customTerm == .matched ? ", \(customTermWord) aroması" : ""
            switch scenario.textAllergen {
            case .content:
                return "süt, şeker" + customTermSuffix
            case .trace:
                return "eser miktarda süt içerebilir" + customTermSuffix
            case .absent:
                switch scenario.language {
                case .recognized: return "su, şeker" + customTermSuffix
                case .unrecognized: return "Мука, сахар, молоко"
                }
            }
        }
    }

    private static func actualOutcome(for scenario: Scenario) -> ExpectedOutcome {
        let offAllergens: Set<Allergen> = scenario.offTag == .present ? [targetAllergen] : []
        let product = Product(
            barcode: "decision-table",
            name: "Karar Tablosu Testi",
            brand: nil,
            imageURL: nil,
            ingredientsText: makeIngredientsText(scenario),
            allergens: offAllergens,
            traces: [],
            categories: [],
            type: scenario.productType == .cosmetic ? .cosmetic : .food
        )
        let userAllergens: Set<Allergen> = scenario.profile == .full ? [targetAllergen] : []
        let customTerms: [String] = scenario.profile == .full ? [customTermWord] : []

        let result = CheckProductUseCase().execute(product: product, userAllergens: userAllergens, customTerms: customTerms)
        let finalResult = MissingIngredientsHeadingRule.apply(to: result, headingFound: scenario.heading == .found)

        return ExpectedOutcome(
            status: finalResult.status,
            isProfileEmpty: finalResult.isProfileEmpty,
            isCosmeticNotSupported: finalResult.isCosmeticNotSupported,
            isMissingIngredientsHeading: finalResult.isMissingIngredientsHeading
        )
    }

    /// `CheckProductUseCase`, `MissingIngredientsHeadingRule` ve CLAUDE.md'deki temkinli
    /// ilkelerin bağımsız, elle yazılmış yeniden ifadesi. Üretim kodunu ÇAĞIRMAZ.
    private static func expectedOutcome(for scenario: Scenario) -> ExpectedOutcome {
        if scenario.productType == .cosmetic {
            return ExpectedOutcome(status: .unknown, isProfileEmpty: false, isCosmeticNotSupported: true, isMissingIngredientsHeading: false)
        }

        let userAllergens: Set<Allergen> = scenario.profile == .full ? [targetAllergen] : []
        let customTerms: [String] = scenario.profile == .full ? [customTermWord] : []

        guard !(userAllergens.isEmpty && customTerms.isEmpty) else {
            return ExpectedOutcome(status: .unknown, isProfileEmpty: true, isCosmeticNotSupported: false, isMissingIngredientsHeading: false)
        }

        let textIsFull = scenario.textPresence == .full
        let noIngredientsText = !textIsFull

        var contains: Set<Allergen> = []
        var mayContain: Set<Allergen> = []
        var isUnrecognizedLanguage = false

        if textIsFull {
            switch scenario.textAllergen {
            case .content: contains = [targetAllergen]
            case .trace: mayContain = [targetAllergen]
            case .absent: isUnrecognizedLanguage = scenario.language == .unrecognized
            }
        }

        if isUnrecognizedLanguage {
            return ExpectedOutcome(status: .unknown, isProfileEmpty: false, isCosmeticNotSupported: false, isMissingIngredientsHeading: false)
        }

        let offAllergens: Set<Allergen> = scenario.offTag == .present ? [targetAllergen] : []
        let textMentioned = contains.union(mayContain)
        let offOnly = offAllergens.subtracting(textMentioned)
        let allContains = contains.union(offOnly)
        let allTraces = mayContain

        let matchedAllergens = allContains.intersection(userAllergens)
        let matchedTraces = allTraces.intersection(userAllergens).subtracting(matchedAllergens)
        let matchedCustomTerms: [String] = (textIsFull && scenario.customTerm == .matched) ? [customTermWord] : []

        let unknownDueToMissingOfficialData = offAllergens.isEmpty && noIngredientsText
        let unknownDueToUncheckedCustomTerms = !customTerms.isEmpty && noIngredientsText

        var status: CheckStatus
        if !matchedAllergens.isEmpty || !matchedCustomTerms.isEmpty {
            status = .unsafe
        } else if !matchedTraces.isEmpty {
            status = .caution
        } else if unknownDueToMissingOfficialData || unknownDueToUncheckedCustomTerms {
            status = .unknown
        } else {
            status = .safe
        }

        var isMissingHeading = false
        if scenario.heading == .notFound, status == .safe {
            status = .unknown
            isMissingHeading = true
        }

        return ExpectedOutcome(status: status, isProfileEmpty: false, isCosmeticNotSupported: false, isMissingIngredientsHeading: isMissingHeading)
    }

    @Test("Karar tablosu: tüm kombinasyonlar dokümante edilen kuralla eşleşir", arguments: allScenarios())
    private func decisionMatchesExpectation(_ scenario: Scenario) {
        let expected = Self.expectedOutcome(for: scenario)
        let actual = Self.actualOutcome(for: scenario)

        #expect(actual == expected, "senaryo: \(scenario.testDescription)")
    }

    @Test("Karar tablosunda test edilen toplam kombinasyon sayısı raporlanır")
    func reportsCombinationCount() {
        let count = Self.allScenarios().count
        print("\n=== Karar tablosu ===")
        print("Test edilen toplam kombinasyon sayısı: \(count)")
        #expect(count > 0)
    }
}
