import Foundation

/// "Tüm verilerimi sil": kullanıcının bu cihazdaki TÜM kalıcı verisini tek yerden siler —
/// barkod hafızası, tarama geçmişi, profil (alerjenler/özel terimler/isim/onboarding
/// bayrağı) ve ağ yanıt önbelleği (ör. ürün görselleri). Bu dört depo birbirinden
/// bağımsız olduğundan sıra işlevsel olarak önemli değildir; okunabilirlik için hafıza →
/// geçmiş → profil → önbellek sırasıyla yapılır.
struct DeleteAllUserDataUseCase {
    private let savedIngredientsTextRepository: SavedIngredientsTextRepository
    private let scanHistoryRepository: ScanHistoryRepository
    private let userProfileRepository: UserProfileRepository

    init(
        savedIngredientsTextRepository: SavedIngredientsTextRepository,
        scanHistoryRepository: ScanHistoryRepository,
        userProfileRepository: UserProfileRepository
    ) {
        self.savedIngredientsTextRepository = savedIngredientsTextRepository
        self.scanHistoryRepository = scanHistoryRepository
        self.userProfileRepository = userProfileRepository
    }

    func execute() {
        savedIngredientsTextRepository.deleteAll()
        scanHistoryRepository.deleteAll()
        userProfileRepository.resetAll()
        URLCache.shared.removeAllCachedResponses()
    }
}
