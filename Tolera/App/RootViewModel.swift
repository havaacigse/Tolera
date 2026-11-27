import Observation

@Observable
final class RootViewModel {
    private(set) var hasCompletedOnboarding: Bool
    /// `RootView` bunu `OnboardingView`'a geçirir. "Tüm verilerimi sil" sonrası bu
    /// TAMAMEN YENİ bir örnekle değiştirilir (bkz. `allDataDeleted()`) — sadece alanlarını
    /// sıfırlamak yerine yeni örnek kurmak en temiz yol: `OnboardingViewModel`'in kendi
    /// varsayılan değerleri (`step = .welcome`, boş isim, boş alerjen seçimi) zaten
    /// "sıfırlanmış" durumu TANIMLAR, bu yüzden ayrıca bir `reset()` metodu yazıp onu
    /// unutmadan her çağırmaya güvenmek gerekmez; yeni bir örnek bunu otomatik garanti eder.
    private(set) var onboardingViewModel: OnboardingViewModel

    private let repository: UserProfileRepository

    init(repository: UserProfileRepository) {
        self.repository = repository
        self.hasCompletedOnboarding = repository.hasCompletedOnboarding()
        self.onboardingViewModel = OnboardingViewModel(repository: repository)
    }

    func onboardingFinished() {
        hasCompletedOnboarding = true
    }

    /// "Tüm verilerimi sil" sonrası çağrılır: onboarding bayrağı `UserProfileRepository.
    /// resetAll()` ile zaten silinmiştir; bu, `RootView`'ın kendi (bellekteki) kopyasını
    /// güncelleyip onboarding ekranına dönmesini sağlar. `onboardingViewModel`'i de YENİDEN
    /// kurar — aksi halde eski örnek, kullanıcının önceki (artık silinmiş) isim/alerjen
    /// seçimini hâlâ bellekte taşırdı (bu ViewModel uygulama ömrü boyunca tek örnek olarak
    /// yaşar, `OnboardingView` kapandıktan sonra da kendiliğinden sıfırlanmaz).
    func allDataDeleted() {
        hasCompletedOnboarding = false
        onboardingViewModel = OnboardingViewModel(repository: repository)
    }
}
