import SwiftUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    @State private var isEditingName = false

    init(viewModel: ProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hassasiyetlerim")
                            .font(.headline)

                        AllergenCardGrid(selected: viewModel.selectedAllergens) { allergen in
                            viewModel.toggle(allergen)
                        }
                    }

                    Text("Bilgilerin sadece bu cihazda saklanır.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Profil")
        }
    }

    private var header: some View {
        HStack {
            if isEditingName {
                TextField("Adın", text: $viewModel.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2.bold())
                    .onSubmit(commitName)

                Button("Tamam", action: commitName)
            } else {
                Text(viewModel.greeting)
                    .font(.title2.bold())

                Spacer()

                Button {
                    isEditingName = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
    }

    private func commitName() {
        viewModel.saveName()
        isEditingName = false
    }
}

#Preview {
    ProfileView(viewModel: ProfileViewModel(repository: UserProfileRepositoryImpl()))
}
