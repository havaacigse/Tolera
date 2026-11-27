import Observation

@Observable
final class ProfileViewModel {
    private(set) var selectedAllergens: Set<Allergen>
    private(set) var customTerms: [String]
    var name: String
    private let repository: UserProfileRepository
    private let deleteAllUserDataUseCase: DeleteAllUserDataUseCase

    init(repository: UserProfileRepository, deleteAllUserDataUseCase: DeleteAllUserDataUseCase) {
        self.repository = repository
        self.deleteAllUserDataUseCase = deleteAllUserDataUseCase
        self.selectedAllergens = repository.loadAllergens()
        self.name = repository.loadName() ?? ""
        self.customTerms = repository.loadCustomTerms()
    }

    var greeting: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Hoş geldin 👋" : "Merhaba \(trimmed) 👋"
    }

    func isSelected(_ allergen: Allergen) -> Bool {
        selectedAllergens.contains(allergen)
    }

    func toggle(_ allergen: Allergen) {
        if selectedAllergens.contains(allergen) {
            selectedAllergens.remove(allergen)
        } else {
            selectedAllergens.insert(allergen)
        }
        repository.save(allergens: selectedAllergens)
    }

    func saveName() {
        repository.save(name: name)
        name = repository.loadName() ?? ""
    }

    func addCustomTerm(_ term: String) {
        guard !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        customTerms.append(term)
        repository.save(customTerms: customTerms)
        customTerms = repository.loadCustomTerms()
    }

    func removeCustomTerm(_ term: String) {
        customTerms.removeAll { $0 == term }
        repository.save(customTerms: customTerms)
        customTerms = repository.loadCustomTerms()
    }

    /// Profil verisini depodan yeniden okur. Bu ViewModel uygulama ömrü boyunca TEK bir
    /// örnek olarak yaşar; "Tüm verilerimi sil" sonrası yeniden onboarding'den geçilip yeni
    /// bir isim/alerjen kaydedilirse (bkz. `OnboardingViewModel.finish()`), bu ViewModel
    /// kendiliğinden haberdar olmaz — hâlâ `init` anındaki eski kopyayı tutar. `ProfileView`
    /// her göründüğünde bu çağrılmalı.
    func refresh() {
        selectedAllergens = repository.loadAllergens()
        name = repository.loadName() ?? ""
        customTerms = repository.loadCustomTerms()
    }

    /// "Tüm verilerimi sil": barkod hafızası, tarama geçmişi, profil ve ağ önbelleğinin
    /// tamamını siler (bkz. `DeleteAllUserDataUseCase`). Çağıran taraf (`ProfileView`),
    /// bundan sonra uygulamayı onboarding ekranına döndürmelidir — bu ViewModel navigasyonu
    /// kendisi tetiklemez.
    func deleteAllData() {
        deleteAllUserDataUseCase.execute()
    }
}
