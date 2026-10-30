import Foundation

final class UserProfileRepositoryImpl: UserProfileRepository {
    private static let allergensKey = "user.allergens"
    private static let nameKey = "user.name"
    private static let onboardingCompletedKey = "user.onboardingCompleted"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAllergens() -> Set<Allergen> {
        let rawValues = defaults.stringArray(forKey: Self.allergensKey) ?? []
        return Set(rawValues.compactMap(Allergen.init(rawValue:)))
    }

    func save(allergens: Set<Allergen>) {
        defaults.set(allergens.map(\.rawValue), forKey: Self.allergensKey)
    }

    func loadName() -> String? {
        defaults.string(forKey: Self.nameKey)
    }

    func save(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: Self.nameKey)
        } else {
            defaults.set(trimmed, forKey: Self.nameKey)
        }
    }

    func hasCompletedOnboarding() -> Bool {
        defaults.bool(forKey: Self.onboardingCompletedKey)
    }

    func setOnboardingCompleted() {
        defaults.set(true, forKey: Self.onboardingCompletedKey)
    }
}
