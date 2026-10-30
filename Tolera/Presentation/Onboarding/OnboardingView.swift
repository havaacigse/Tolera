import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    private let onFinished: () -> Void

    init(viewModel: OnboardingViewModel, onFinished: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
    }

    var body: some View {
        VStack {
            switch viewModel.step {
            case .welcome:
                welcomeStep
            case .name:
                nameStep
            case .allergens:
                allergensStep
            }
        }
        .padding()
    }

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🌾🥛🥜")
                .font(.system(size: 56))

            Text("Tolera'ya Hoş Geldin")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Barkodunu okut, alerjen ve hassasiyetlerine göre bu ürünün senin için uygun olup olmadığını hemen öğren.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Başla") {
                viewModel.goToNextStep()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var nameStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Sana nasıl hitap edelim?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            TextField("Adın (opsiyonel)", text: $viewModel.name)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Devam") {
                viewModel.goToNextStep()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var allergensStep: some View {
        VStack(spacing: 20) {
            Text("Hangi içeriklerden uzak durman gerekiyor?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            ScrollView {
                AllergenCardGrid(selected: viewModel.selectedAllergens) { allergen in
                    viewModel.toggleAllergen(allergen)
                }
            }

            Button("Başla") {
                viewModel.finish()
                onFinished()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel(repository: UserProfileRepositoryImpl())) {}
}
