import Observation

@Observable
final class ProfileViewModel {
    private(set) var selectedAllergens: Set<Allergen>
    var name: String
    private let repository: UserProfileRepository

    init(repository: UserProfileRepository) {
        self.repository = repository
        self.selectedAllergens = repository.loadAllergens()
        self.name = repository.loadName() ?? ""
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
}
