import Foundation
import Testing
@testable import Tolera

/// golden_set.json'daki her etiketli (annotated) üründen, gerçek dünyada OCR/kullanıcı
/// kaynaklı olabilecek bozulmuş sürümler üretir (Türkçe karakter kaybı, noktalama kaybı,
/// tamamı büyük harf, rastgele satır sonu) ve dedektörün her sürümde kaç "tehlikeli hata"
/// (gerçek içerik alerjeninin kaçırılması) ve kaç "eser miktar kaçırması" yaptığını raporlar.
struct IngredientTextCorruptionRobustnessTests {
    private struct GoldenSetEntry: Codable {
        let barcode: String
        let name: String
        let ingredientsText: String
        let expectedContains: [String]
        let expectedMayContain: [String]
        let annotated: Bool
    }

    private enum Corruption: String, CaseIterable {
        case sToS = "ş→s"
        case sToG = "ş→g"
        case dotlessIToI = "ı→i"
        case gToG = "ğ→g"
        case cToC = "ç→c"
        case removePunctuation = "noktalama silme"
        case uppercase = "tamamı büyük harf"
        case randomLineBreaks = "rastgele satır sonu"
    }

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

    private struct MissReport {
        let entryName: String
        let barcode: String
        let missedContains: [Allergen]
        let missedTraces: [Allergen]
        let corruptedText: String
    }

    private func corrupt(_ corruption: Corruption, _ text: String, rng: inout SeededGenerator) -> String {
        switch corruption {
        case .sToS:
            return text.replacingOccurrences(of: "ş", with: "s").replacingOccurrences(of: "Ş", with: "S")
        case .sToG:
            return text.replacingOccurrences(of: "ş", with: "g").replacingOccurrences(of: "Ş", with: "G")
        case .dotlessIToI:
            return text.replacingOccurrences(of: "ı", with: "i")
        case .gToG:
            return text.replacingOccurrences(of: "ğ", with: "g").replacingOccurrences(of: "Ğ", with: "G")
        case .cToC:
            return text.replacingOccurrences(of: "ç", with: "c").replacingOccurrences(of: "Ç", with: "C")
        case .removePunctuation:
            return text.components(separatedBy: CharacterSet.punctuationCharacters).joined(separator: " ")
        case .uppercase:
            // Türkçe locale ile: i/İ ve ı/I dönüşümü doğru yönde olsun (OCR/kullanıcı
            // tamamen büyük harf yazarsa gerçekte böyle davranır).
            return text.uppercased(with: Locale(identifier: "tr_TR"))
        case .randomLineBreaks:
            // OCR'ın kelimelerin ortasından satır kaydırdığı durumları simüle eder.
            var result = ""
            for character in text {
                result.append(character)
                if character == " ", Int.random(in: 0..<4, using: &rng) == 0 {
                    result.append("\n")
                }
            }
            return result
        }
    }

    @Test("Bozulmaya dayanıklılık: golden set üzerinde Türkçe karakter/biçim bozulmaları")
    func detectorSurvivesTextCorruption() throws {
        let entries = try loadGoldenSet().filter(\.annotated)
        let detector = IngredientAllergenDetector()
        var rng = SeededGenerator(seed: 987_654_321)

        var dangerousCountByCorruption: [Corruption: Int] = [:]
        var traceMissCountByCorruption: [Corruption: Int] = [:]
        var reportsByCorruption: [Corruption: [MissReport]] = [:]

        for corruption in Corruption.allCases {
            var dangerousCount = 0
            var traceMissCount = 0
            var reports: [MissReport] = []

            for entry in entries {
                let expectedContains = Set(entry.expectedContains.compactMap(Allergen.init(rawValue:)))
                let expectedMayContain = Set(entry.expectedMayContain.compactMap(Allergen.init(rawValue:)))
                guard !expectedContains.isEmpty || !expectedMayContain.isEmpty else { continue }

                // Gerçek akışla aynı temizlik sırası: OFF biçimlendirmesi temizlenir, bozulma
                // uygulanır, sonra OCR akışındaki satır sonu/boşluk temizliği uygulanır.
                let cleanedOriginal = IngredientsTextCleaner.clean(entry.ingredientsText)
                let corrupted = corrupt(corruption, cleanedOriginal, rng: &rng)
                let finalText = OCRTextCleaner.clean(corrupted)

                let result = detector.detect(in: finalText)

                let missedContains = expectedContains.subtracting(result.contains)
                let missedTraces = expectedMayContain.subtracting(result.mayContain.union(result.contains))

                if !missedContains.isEmpty {
                    dangerousCount += 1
                    reports.append(MissReport(
                        entryName: entry.name, barcode: entry.barcode,
                        missedContains: Array(missedContains).sorted { $0.displayName < $1.displayName },
                        missedTraces: [], corruptedText: finalText
                    ))
                }
                if !missedTraces.isEmpty {
                    traceMissCount += 1
                    reports.append(MissReport(
                        entryName: entry.name, barcode: entry.barcode,
                        missedContains: [],
                        missedTraces: Array(missedTraces).sorted { $0.displayName < $1.displayName },
                        corruptedText: finalText
                    ))
                }
            }

            dangerousCountByCorruption[corruption] = dangerousCount
            traceMissCountByCorruption[corruption] = traceMissCount
            reportsByCorruption[corruption] = reports
        }

        print("\n=== Bozulmaya dayanıklılık raporu (golden set, \(entries.count) etiketli ürün) ===")
        var totalDangerous = 0
        var totalTraceMiss = 0
        for corruption in Corruption.allCases {
            let dangerous = dangerousCountByCorruption[corruption] ?? 0
            let traceMiss = traceMissCountByCorruption[corruption] ?? 0
            totalDangerous += dangerous
            totalTraceMiss += traceMiss
            print("- \(corruption.rawValue): tehlikeli hata = \(dangerous), eser miktar kaçırma = \(traceMiss)")
            for report in reportsByCorruption[corruption] ?? [] {
                if !report.missedContains.isEmpty {
                    print("    [TEHLİKELİ] \(report.entryName) (\(report.barcode)): kaçırılan içerik -> \(report.missedContains.map(\.displayName).joined(separator: ", "))")
                    print("      bozulmuş metin: \(report.corruptedText)")
                }
                if !report.missedTraces.isEmpty {
                    print("    [eser miktar] \(report.entryName) (\(report.barcode)): kaçırılan eser miktar -> \(report.missedTraces.map(\.displayName).joined(separator: ", "))")
                }
            }
        }
        print("TOPLAM tehlikeli hata: \(totalDangerous), TOPLAM eser miktar kaçırma: \(totalTraceMiss)")

        #expect(totalDangerous == 0, "Bozulma sonrası tehlikeli hata(lar) var, yukarıdaki raporu incele.")
    }

    private func loadGoldenSet() throws -> [GoldenSetEntry] {
        let thisFile = URL(fileURLWithPath: #filePath)
        let jsonURL = thisFile
            .deletingLastPathComponent()
            .appendingPathComponent("EvaluationData/golden_set.json")
        let data = try Data(contentsOf: jsonURL)
        return try JSONDecoder().decode([GoldenSetEntry].self, from: data)
    }
}
