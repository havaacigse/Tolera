import Testing
@testable import Tolera

/// `RootViewModel`'in "Tüm verilerimi sil" sonrası davranışını test eder: bellekte eski
/// isim/alerjen seçimi kalmaması için `onboardingViewModel` tamamen YENİ bir örnekle
/// değiştirilmeli (sadece bayrakları sıfırlamak yetmez, eski örnek hâlâ eski state'i taşır).
struct RootViewModelTests {
    private final class MockUserProfileRepository: UserProfileRepository, @unchecked Sendable {
        var allergens: Set<Allergen> = []
        var customTerms: [String] = []
        var name: String?
        var onboardingCompleted = false

        func loadAllergens() -> Set<Allergen> { allergens }
        func save(allergens: Set<Allergen>) { self.allergens = allergens }
        func loadName() -> String? { name }
        func save(name: String) { self.name = name }
        func hasCompletedOnboarding() -> Bool { onboardingCompleted }
        func setOnboardingCompleted() { onboardingCompleted = true }
        func loadCustomTerms() -> [String] { customTerms }
        func save(customTerms: [String]) { self.customTerms = customTerms }
        func resetAll() {
            allergens = []
            customTerms = []
            name = nil
            onboardingCompleted = false
        }
    }

    @Test("Tüm veriler silindikten sonra onboarding ilk adımdan, boş isim ve boş alerjen seçimiyle başlar")
    func allDataDeletedResetsOnboardingViewModelToFreshState() {
        let repository = MockUserProfileRepository()
        let viewModel = RootViewModel(repository: repository)

        // Kullanıcı daha önce onboarding'den geçip bir isim/alerjen seçmiş, son adıma gelmiş olsun.
        viewModel.onboardingViewModel.name = "Ayşe"
        viewModel.onboardingViewModel.toggleAllergen(.milk)
        viewModel.onboardingViewModel.goToNextStep()
        viewModel.onboardingViewModel.goToNextStep()

        viewModel.allDataDeleted()

        #expect(viewModel.onboardingViewModel.step == .welcome)
        #expect(viewModel.onboardingViewModel.name == "")
        #expect(viewModel.onboardingViewModel.selectedAllergens.isEmpty)
    }
}
