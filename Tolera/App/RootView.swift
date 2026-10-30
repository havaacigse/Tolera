import SwiftUI

struct RootView: View {
    @State private var viewModel: RootViewModel
    private let onboardingViewModel: OnboardingViewModel
    private let searchViewModel: SearchViewModel
    private let profileViewModel: ProfileViewModel

    init(
        rootViewModel: RootViewModel,
        onboardingViewModel: OnboardingViewModel,
        searchViewModel: SearchViewModel,
        profileViewModel: ProfileViewModel
    ) {
        _viewModel = State(initialValue: rootViewModel)
        self.onboardingViewModel = onboardingViewModel
        self.searchViewModel = searchViewModel
        self.profileViewModel = profileViewModel
    }

    var body: some View {
        if viewModel.hasCompletedOnboarding {
            ContentView(searchViewModel: searchViewModel, profileViewModel: profileViewModel)
        } else {
            OnboardingView(viewModel: onboardingViewModel) {
                viewModel.onboardingFinished()
            }
        }
    }
}
