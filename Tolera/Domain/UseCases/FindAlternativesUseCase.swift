import Foundation

/// Denenen kategorilerin tamamı ağ/sunucu hatasıyla başarısız olduğunda fırlatılır.
/// "Sonuç bulunamadı" (boş dizi) ile "yüklenemedi" durumunu ayırt etmek için kullanılır.
enum FindAlternativesError: Error {
    case loadFailed
}

/// Kullanıcı için uygun olmayan (unsafe/caution) bir ürüne, aynı kategoriden güvenli
/// alternatifler önerir. İçindekiler metni olmayan (unknown) ürünler asla önerilmez;
/// sadece gerçekten "safe" sonuç verenler listelenir.
struct FindAlternativesUseCase {
    private let productRepository: ProductRepository
    private let checkProductUseCase: CheckProductUseCase

    private let maxResults = 5
    private let maxCategoryLevelsUp = 2

    init(
        productRepository: ProductRepository,
        checkProductUseCase: CheckProductUseCase = CheckProductUseCase()
    ) {
        self.productRepository = productRepository
        self.checkProductUseCase = checkProductUseCase
    }

    func execute(
        for product: Product,
        currentStatus: CheckStatus,
        userAllergens: Set<Allergen>,
        customTerms: [String]
    ) async throws -> [Product] {
        // Sadece uygun olmayan sonuçlar için alternatif aranır; safe/unknown'da arama gereksizdir.
        guard currentStatus == .unsafe || currentStatus == .caution else { return [] }
        guard !product.categories.isEmpty else { return [] }

        var alternatives: [Product] = []
        var seenBarcodes: Set<String> = [product.barcode]
        var didAnyCategorySucceed = false

        for category in categoriesFromMostSpecific(product.categories) {
            guard alternatives.count < maxResults else { break }

            let candidates: [Product]
            do {
                candidates = try await productRepository.products(inCategory: category, excludingBarcode: product.barcode)
                didAnyCategorySucceed = true
            } catch {
                // Bu kategori seviyesi başarısız oldu; bir üst kategoriyle devam edilir.
                continue
            }

            for candidate in candidates {
                guard alternatives.count < maxResults else { break }
                guard !seenBarcodes.contains(candidate.barcode) else { continue }
                seenBarcodes.insert(candidate.barcode)

                let result = checkProductUseCase.execute(
                    product: candidate,
                    userAllergens: userAllergens,
                    customTerms: customTerms
                )
                guard result.status == .safe else { continue }

                alternatives.append(candidate)
            }
        }

        // Hiçbir kategori denemesi başarılı olmadıysa bu "sonuç yok" değil "yüklenemedi" demektir.
        guard didAnyCategorySucceed else {
            throw FindAlternativesError.loadFailed
        }

        return alternatives
    }

    /// En spesifik kategoriden (dizinin son elemanı) başlayıp en fazla 2 üst seviyeye
    /// çıkan kategori listesini döndürür (ör. ["biscuits", "biscuits-and-cakes", "snacks"]).
    private func categoriesFromMostSpecific(_ categories: [String]) -> [String] {
        let levelCount = min(1 + maxCategoryLevelsUp, categories.count)
        return categories.suffix(levelCount).reversed()
    }
}
