import Foundation

protocol UserProfileRepository {
    func loadAllergens() -> Set<Allergen>
    func save(allergens: Set<Allergen>)

    func loadName() -> String?
    func save(name: String)

    func hasCompletedOnboarding() -> Bool
    func setOnboardingCompleted()
}
