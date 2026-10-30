import Foundation
import Testing
@testable import Tolera

struct GoldenSetEvaluationTests {
    private struct GoldenSetEntry: Codable {
        let barcode: String
        let name: String
        let ingredientsText: String
        let expectedContains: [String]
        let expectedMayContain: [String]
        let notes: String
        let annotated: Bool
        let offAllergens: [String]
        let offTraces: [String]
    }

    private struct DangerousError {
        let name: String
        let barcode: String
        let missed: [Allergen]
        let ingredientsText: String
    }

    private struct EvaluationSummary {
        var evaluated = 0
        var correct = 0
        var incorrect = 0
        var dangerousErrors: [DangerousError] = []
        var cautiousErrors: [String] = []
        var traceMismatches: [String] = []
    }

    @Test("Golden set üzerinde dedektör ve OFF etiketlerinin karşılaştırmalı değerlendirmesi")
    func evaluateGoldenSet() throws {
        let entries = try loadGoldenSet()
        let detector = IngredientAllergenDetector()

        let detectorSummary = evaluate(entries: entries) { entry in
            let cleaned = IngredientsTextCleaner.clean(entry.ingredientsText)
            let result = detector.detect(in: cleaned)
            return (result.contains, result.mayContain)
        }

        let offSummary = evaluate(entries: entries) { entry in
            let contains = Set(entry.offAllergens.compactMap(Allergen.init(rawValue:)))
            let traces = Set(entry.offTraces.compactMap(Allergen.init(rawValue:)))
            return (contains, traces)
        }

        printReport(methodName: "Dedektör (içindekiler metni)", summary: detectorSummary)
        printReport(methodName: "OFF etiketleri (allergens_tags / traces_tags)", summary: offSummary)

        // Sadece dedektörün tehlikeli hataları testi başarısız kılar; OFF etiketleri sadece raporlanır.
        #expect(detectorSummary.dangerousErrors.isEmpty, "Dedektörde tehlikeli hata(lar) var: gerçek bir alerjen kaçırıldı, yukarıdaki raporu incele.")
    }

    private func evaluate(
        entries: [GoldenSetEntry],
        actual: (GoldenSetEntry) -> (contains: Set<Allergen>, mayContain: Set<Allergen>)
    ) -> EvaluationSummary {
        var summary = EvaluationSummary()

        for entry in entries where entry.annotated {
            let expectedContains = Set(entry.expectedContains.compactMap(Allergen.init(rawValue:)))
            let expectedMayContain = Set(entry.expectedMayContain.compactMap(Allergen.init(rawValue:)))

            summary.evaluated += 1
            let result = actual(entry)

            let missed = expectedContains.subtracting(result.contains)
            let extraContains = result.contains.subtracting(expectedContains)
            let missingTrace = expectedMayContain.subtracting(result.mayContain)
            let extraTrace = result.mayContain.subtracting(expectedMayContain)

            if missed.isEmpty && extraContains.isEmpty && missingTrace.isEmpty && extraTrace.isEmpty {
                summary.correct += 1
            } else {
                summary.incorrect += 1
            }

            if !missed.isEmpty {
                summary.dangerousErrors.append(
                    DangerousError(
                        name: entry.name,
                        barcode: entry.barcode,
                        missed: missed.sorted(by: { $0.displayName < $1.displayName }),
                        ingredientsText: IngredientsTextCleaner.clean(entry.ingredientsText)
                    )
                )
            }

            if !extraContains.isEmpty {
                let names = extraContains.map(\.displayName).sorted().joined(separator: ", ")
                summary.cautiousErrors.append("\(entry.name) (\(entry.barcode)): fazladan yakalanan içerik -> \(names)")
            }

            if !missingTrace.isEmpty || !extraTrace.isEmpty {
                var parts: [String] = []
                if !missingTrace.isEmpty {
                    parts.append("kaçırılan eser miktar: \(missingTrace.map(\.displayName).sorted().joined(separator: ", "))")
                }
                if !extraTrace.isEmpty {
                    parts.append("fazladan eser miktar: \(extraTrace.map(\.displayName).sorted().joined(separator: ", "))")
                }
                summary.traceMismatches.append("\(entry.name) (\(entry.barcode)): \(parts.joined(separator: "; "))")
            }
        }

        return summary
    }

    private func loadGoldenSet() throws -> [GoldenSetEntry] {
        let thisFile = URL(fileURLWithPath: #filePath)
        let jsonURL = thisFile
            .deletingLastPathComponent()
            .appendingPathComponent("EvaluationData/golden_set.json")
        let data = try Data(contentsOf: jsonURL)
        return try JSONDecoder().decode([GoldenSetEntry].self, from: data)
    }

    private func printReport(methodName: String, summary: EvaluationSummary) {
        print("\n=== \(methodName) ===")
        print("Değerlendirilen ürün: \(summary.evaluated) (doğru: \(summary.correct), yanlış: \(summary.incorrect))")

        print("--- TEHLİKELİ hatalar (\(summary.dangerousErrors.count)) ---")
        if summary.dangerousErrors.isEmpty {
            print("Yok.")
        } else {
            for error in summary.dangerousErrors {
                let names = error.missed.map(\.displayName).joined(separator: ", ")
                print("- \(error.name) (\(error.barcode)): kaçırılan -> \(names)")
                print("  metin: \(error.ingredientsText)")
            }
        }

        print("--- Temkinli hatalar (fazladan yakalananlar) (\(summary.cautiousErrors.count)) ---")
        if summary.cautiousErrors.isEmpty {
            print("Yok.")
        } else {
            for line in summary.cautiousErrors {
                print("- \(line)")
            }
        }

        print("--- Eser miktar karışıklıkları (\(summary.traceMismatches.count)) ---")
        if summary.traceMismatches.isEmpty {
            print("Yok.")
        } else {
            for line in summary.traceMismatches {
                print("- \(line)")
            }
        }
    }
}
