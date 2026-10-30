import Observation

@Observable
final class ProfileViewModel {
    private(set) var selectedAllergens: Set<Allergen>
    private(set) var customTerms: [String]
    var name: String
    private let repository: UserProfileRepository

    init(repository: UserProfileRepository) {
        self.repository = repository
        self.selectedAllergens = repository.loadAllergens()
        self.name = repository.loadName() ?? ""
        self.customTerms = repository.loadCustomTerms()
    }

    var greeting: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Hoş geldin 👋" : "Merhaba \(trimmed) 👋"
    }

    func isSelected(_ allergen: Allergen) -> Bool {
        selectedAllergens.contains(allergen)
    }

    func toggle(_ allergen: Allergen) {
        if selectedAllergens.contains(allergen) {
            selectedAllergens.remove(allergen)
        } else {
            selectedAllergens.insert(allergen)
        }
        repository.save(allergens: selectedAllergens)
    }

    func saveName() {
        repository.save(name: name)
        name = repository.loadName() ?? ""
    }

    func addCustomTerm(_ term: String) {
        guard !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        customTerms.append(term)
        repository.save(customTerms: customTerms)
        customTerms = repository.loadCustomTerms()
    }

    func removeCustomTerm(_ term: String) {
        customTerms.removeAll { $0 == term }
        repository.save(customTerms: customTerms)
        customTerms = repository.loadCustomTerms()
    }
}
