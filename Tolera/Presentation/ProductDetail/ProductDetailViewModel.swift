import Observation

/// Bir alternatif ürüne dokunulduğunda açılan detay ekranının view model'i.
/// Sonucu, FindAlternativesUseCase içinde zaten hesaplanmış olsa da, kullanıcının
/// o anki profiliyle (güncel olabilir) kendisi yeniden hesaplar.
@Observable
final class ProductDetailViewModel {
    let result: ProductCheckResult

    init(
        product: Product,
        checkProductUseCase: CheckProductUseCase,
        profileRepository: UserProfileRepository
    ) {
        let userAllergens = profileRepository.loadAllergens()
        let customTerms = profileRepository.loadCustomTerms()
        result = checkProductUseCase.execute(
            product: product,
            userAllergens: userAllergens,
            customTerms: customTerms
        )
    }
}
