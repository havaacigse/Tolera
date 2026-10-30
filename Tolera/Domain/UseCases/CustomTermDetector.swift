import Foundation

struct CustomTermDetector {
    func detect(customTerms: [String], in text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        let normalizedText = TurkishWordMatcher.normalize(text)

        return customTerms.filter { term in
            TurkishWordMatcher.matchesWordStart(keyword: TurkishWordMatcher.normalize(term), in: normalizedText)
        }.map(TurkishWordMatcher.normalize)
    }
}
