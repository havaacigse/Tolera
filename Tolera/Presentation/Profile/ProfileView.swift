import SwiftData
import SwiftUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    @State private var isEditingName = false
    @State private var isAddingCustomTerm = false
    @State private var newCustomTerm = ""
    let onAllDataDeleted: () -> Void

    init(viewModel: ProfileViewModel, onAllDataDeleted: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAllDataDeleted = onAllDataDeleted
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

                    customTermsSection

                    Text("Bilgilerin sadece bu cihazda saklanır.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Profil")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(viewModel: viewModel, onAllDataDeleted: onAllDataDeleted)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .alert("Yeni hassasiyet", isPresented: $isAddingCustomTerm) {
            TextField("Örn. çilek", text: $newCustomTerm)
            Button("Ekle") {
                viewModel.addCustomTerm(newCustomTerm)
                newCustomTerm = ""
            }
            Button("Vazgeç", role: .cancel) {
                newCustomTerm = ""
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    private var customTermsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diğer hassasiyetlerim")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(viewModel.customTerms, id: \.self) { term in
                    HStack(spacing: 4) {
                        Text(term)
                        Button {
                            viewModel.removeCustomTerm(term)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                }

                Button {
                    isAddingCustomTerm = true
                } label: {
                    Label("Ekle", systemImage: "plus")
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
            }
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
    let modelContainer = try! ModelContainer(
        for: SavedIngredientsTextModel.self, ScanHistoryEntryModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ProfileView(
        viewModel: ProfileViewModel(
            repository: UserProfileRepositoryImpl(),
            deleteAllUserDataUseCase: DeleteAllUserDataUseCase(
                savedIngredientsTextRepository: SavedIngredientsTextRepositoryImpl(modelContainer: modelContainer),
                scanHistoryRepository: ScanHistoryRepositoryImpl(modelContainer: modelContainer),
                userProfileRepository: UserProfileRepositoryImpl()
            )
        ),
        onAllDataDeleted: {}
    )
}
