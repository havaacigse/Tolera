import Foundation
import Testing
@testable import Tolera

/// Sabit seed'li rastgele metin üretimiyle `CheckProductUseCase`'in temkinli ilkelerini
/// geniş bir girdi uzayında sınayan özellik (property-based) testi. Gerçek içindekiler
/// parçalarından rastgele metinler kurar ve dört güvenlik kuralını kontrol eder:
/// A) kullanıcının alerjeni içerik olarak geçiyorsa asla safe olmaz,
/// B) metin yoksa / profil boşsa / kozmetikse asla safe olmaz,
/// C) metne içerik eklemek sonucu daha güvenli yapamaz,
/// D) profile alerjen eklemek sonucu daha güvenli yapamaz.
struct CheckProductSafetyInvariantTests {
    private struct Fragment {
        let text: String
        let allergens: Set<Allergen>
    }

    // Gerçek, tek anlamlı anahtar kelimelerden oluşan içerik parçaları. Hiçbiri "eser
    // miktarda"/"içerebilir" gibi tetikleyici ifade barındırmaz; bu yüzden birleştirildiklerinde
    // hepsi "içerik" (contains) sayılmalıdır — zemin gerçeği (ground truth) budur.
    private static let contentFragments: [Fragment] = [
        Fragment(text: "buğday unu", allergens: [.gluten]),
        Fragment(text: "arpa", allergens: [.gluten]),
        Fragment(text: "yulaf", allergens: [.gluten]),
        Fragment(text: "süt tozu", allergens: [.milk]),
        Fragment(text: "tam yağlı süt", allergens: [.milk]),
        Fragment(text: "yoğurt", allergens: [.milk]),
        Fragment(text: "yumurta", allergens: [.eggs]),
        Fragment(text: "yumurta akı", allergens: [.eggs]),
        Fragment(text: "balık yağı", allergens: [.fish]),
        Fragment(text: "somon", allergens: [.fish]),
        Fragment(text: "karides", allergens: [.crustaceans]),
        Fragment(text: "yengeç eti", allergens: [.crustaceans]),
        Fragment(text: "midye", allergens: [.molluscs]),
        Fragment(text: "kalamar", allergens: [.molluscs]),
        Fragment(text: "yer fıstığı", allergens: [.peanuts]),
        Fragment(text: "fındık", allergens: [.nuts]),
        Fragment(text: "badem", allergens: [.nuts]),
        Fragment(text: "ceviz", allergens: [.nuts]),
        Fragment(text: "soya lesitini", allergens: [.soybeans]),
        Fragment(text: "kereviz", allergens: [.celery]),
        Fragment(text: "hardal", allergens: [.mustard]),
        Fragment(text: "susam", allergens: [.sesame]),
        Fragment(text: "tahin", allergens: [.sesame]),
        Fragment(text: "sülfit", allergens: [.sulphites]),
        Fragment(text: "acı bakla", allergens: [.lupin])
    ]

    private static let neutralFragments: [Fragment] = [
        "şeker", "tuz", "su", "nişasta", "aroma vericiler", "kabartıcı",
        "sodyum bikarbonat", "palm yağı", "vanilya", "limon kabuğu", "karbonat", "maya", "sitrik asit"
    ].map { Fragment(text: $0, allergens: []) }

    private static var allFragments: [Fragment] { contentFragments + neutralFragments }

    /// Basit, deterministik xorshift64 üreteci: aynı seed her çalıştırmada aynı metinleri verir.
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0xdead_beef : seed }
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }

    private struct Violation {
        let rule: String
        let text: String
        let detail: String
    }

    /// "Daha güvenli" sıralaması: safe en güvenli, unsafe en az güvenli.
    private static func severityRank(_ status: CheckStatus) -> Int {
        switch status {
        case .unsafe: return 0
        case .caution: return 1
        case .unknown: return 2
        case .safe: return 3
        }
    }

    private func makeProduct(ingredientsText: String?, type: ProductType = .food) -> Product {
        Product(
            barcode: "random-test", name: "Rastgele Test Ürünü", brand: nil, imageURL: nil,
            ingredientsText: ingredientsText, allergens: [], traces: [], categories: [], type: type
        )
    }

    @Test("Güvenlik kuralları: sabit seed'li en az 2000 rastgele metin üzerinde kontrol")
    func safetyRulesHoldAcrossRandomTexts() {
        var rng = SeededGenerator(seed: 1_234_567)
        let useCase = CheckProductUseCase()
        var violations: [Violation] = []
        let iterationCount = 2000
        var generatedTextCount = 0

        for _ in 0..<iterationCount {
            let fragmentCount = Int.random(in: 2...6, using: &rng)
            var baseFragments: [Fragment] = []
            for _ in 0..<fragmentCount {
                baseFragments.append(Self.allFragments.randomElement(using: &rng)!)
            }
            let baseText = baseFragments.map(\.text).joined(separator: ", ")
            let groundTruthAllergens = Set(baseFragments.flatMap(\.allergens))
            generatedTextCount += 1

            let profileAllergen: Allergen
            if !groundTruthAllergens.isEmpty, Bool.random(using: &rng) {
                profileAllergen = groundTruthAllergens.randomElement(using: &rng)!
            } else {
                profileAllergen = Allergen.allCases.randomElement(using: &rng)!
            }
            let userAllergens: Set<Allergen> = [profileAllergen]
            let baseProduct = makeProduct(ingredientsText: baseText)
            let baseResult = useCase.execute(product: baseProduct, userAllergens: userAllergens, customTerms: [])

            // Kural A: kullanıcının alerjeni gerçekten içerikte geçiyorsa asla safe olmaz,
            // ve dedektör bu alerjeni kaçırmamalı (tehlikeli hata olurdu).
            if groundTruthAllergens.contains(profileAllergen) {
                if baseResult.status == .safe {
                    violations.append(Violation(
                        rule: "A: alerjen içerikte geçiyor ama sonuç safe",
                        text: baseText,
                        detail: "profil=\(profileAllergen.rawValue), durum=\(baseResult.status)"
                    ))
                }
                if !baseResult.matchedAllergens.contains(profileAllergen) {
                    violations.append(Violation(
                        rule: "A: dedektör gerçek içerikteki alerjeni kaçırdı",
                        text: baseText,
                        detail: "profil=\(profileAllergen.rawValue) metinde olmalıydı, matchedAllergens=\(baseResult.matchedAllergens)"
                    ))
                }
            }

            // Kural B: metin yoksa / profil boşsa / kozmetikse asla safe olmaz.
            let nilTextResult = useCase.execute(product: makeProduct(ingredientsText: nil), userAllergens: userAllergens, customTerms: [])
            if nilTextResult.status == .safe {
                violations.append(Violation(rule: "B: metin nil ama safe", text: "(nil)", detail: "profil=\(profileAllergen.rawValue)"))
            }
            let emptyTextResult = useCase.execute(product: makeProduct(ingredientsText: ""), userAllergens: userAllergens, customTerms: [])
            if emptyTextResult.status == .safe {
                violations.append(Violation(rule: "B: metin boş ama safe", text: "(boş)", detail: "profil=\(profileAllergen.rawValue)"))
            }
            let emptyProfileResult = useCase.execute(product: baseProduct, userAllergens: [], customTerms: [])
            if emptyProfileResult.status == .safe {
                violations.append(Violation(rule: "B: profil boş ama safe", text: baseText, detail: ""))
            }
            let cosmeticResult = useCase.execute(product: makeProduct(ingredientsText: baseText, type: .cosmetic), userAllergens: userAllergens, customTerms: [])
            if cosmeticResult.status == .safe {
                violations.append(Violation(rule: "B: kozmetik ama safe", text: baseText, detail: ""))
            }

            // Kural C: metne (aynı profille) içerik eklemek sonucu daha güvenli yapamaz.
            let extraFragment = Self.allFragments.randomElement(using: &rng)!
            let extendedText = baseText + ", " + extraFragment.text
            generatedTextCount += 1
            let extendedResult = useCase.execute(product: makeProduct(ingredientsText: extendedText), userAllergens: userAllergens, customTerms: [])
            if Self.severityRank(extendedResult.status) > Self.severityRank(baseResult.status) {
                violations.append(Violation(
                    rule: "C: metne içerik eklemek sonucu daha güvenli yaptı",
                    text: extendedText,
                    detail: "öncesi=\(baseResult.status) sonrası=\(extendedResult.status), profil=\(profileAllergen.rawValue)"
                ))
            }

            // Kural D: aynı metinle profile alerjen eklemek sonucu daha güvenli yapamaz.
            let otherAllergens = Allergen.allCases.filter { $0 != profileAllergen }
            let extraAllergen = otherAllergens.randomElement(using: &rng)!
            let expandedProfileResult = useCase.execute(product: baseProduct, userAllergens: [profileAllergen, extraAllergen], customTerms: [])
            if Self.severityRank(expandedProfileResult.status) > Self.severityRank(baseResult.status) {
                violations.append(Violation(
                    rule: "D: profile alerjen eklemek sonucu daha güvenli yaptı",
                    text: baseText,
                    detail: "öncesi=\(baseResult.status) sonrası=\(expandedProfileResult.status), profil=[\(profileAllergen.rawValue), \(extraAllergen.rawValue)]"
                ))
            }
        }

        print("\n=== Güvenlik kuralları rastgele testi ===")
        print("İterasyon (senaryo) sayısı: \(iterationCount)")
        print("Üretilen gerçek metin sayısı: \(generatedTextCount)")
        print("İhlal sayısı: \(violations.count)")
        for violation in violations.prefix(50) {
            print("- [\(violation.rule)] metin: \"\(violation.text)\" | \(violation.detail)")
        }

        #expect(violations.isEmpty, "Güvenlik kuralı ihlali bulundu, yukarıdaki raporu incele.")
    }
}
