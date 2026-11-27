import SwiftUI

struct RootView: View {
    @State private var viewModel: RootViewModel
    private let searchViewModel: SearchViewModel
    private let historyViewModel: HistoryViewModel
    private let profileViewModel: ProfileViewModel

    init(
        rootViewModel: RootViewModel,
        searchViewModel: SearchViewModel,
        historyViewModel: HistoryViewModel,
        profileViewModel: ProfileViewModel
    ) {
        _viewModel = State(initialValue: rootViewModel)
        self.searchViewModel = searchViewModel
        self.historyViewModel = historyViewModel
        self.profileViewModel = profileViewModel
    }

    var body: some View {
        if viewModel.hasCompletedOnboarding {
            ContentView(
                searchViewModel: searchViewModel,
                historyViewModel: historyViewModel,
                profileViewModel: profileViewModel,
                onAllDataDeleted: {
                    viewModel.allDataDeleted()
                    searchViewModel.reset()
                }
            )
        } else {
            // `viewModel.onboardingViewModel`: "Tüm verilerimi sil" sonrası RootViewModel
            // tarafından YENİ bir örnekle değiştirilmiş olabilir (bkz. `allDataDeleted()`),
            // bu yüzden burada sabit bir property değil, doğrudan ViewModel'den okunur.
            OnboardingView(viewModel: viewModel.onboardingViewModel) {
                viewModel.onboardingFinished()
            }
        }
    }
}
