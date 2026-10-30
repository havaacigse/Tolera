import Observation

@Observable
final class OnboardingViewModel {
    enum Step: Int {
        case welcome
        case name
        case allergens
    }

    var step: Step = .welcome
    var name: String = ""
    var selectedAllergens: Set<Allergen> = []

    private let repository: UserProfileRepository

    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    func goToNextStep() {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        }
    }

    func toggleAllergen(_ allergen: Allergen) {
        if selectedAllergens.contains(allergen) {
            selectedAllergens.remove(allergen)
        } else {
            selectedAllergens.insert(allergen)
        }
    }

    func finish() {
        repository.save(name: name)
        repository.save(allergens: selectedAllergens)
        repository.setOnboardingCompleted()
    }
}
