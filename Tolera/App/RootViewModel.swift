import Observation

@Observable
final class RootViewModel {
    private(set) var hasCompletedOnboarding: Bool

    private let repository: UserProfileRepository

    init(repository: UserProfileRepository) {
        self.repository = repository
        self.hasCompletedOnboarding = repository.hasCompletedOnboarding()
    }

    func onboardingFinished() {
        hasCompletedOnboarding = true
    }
}
