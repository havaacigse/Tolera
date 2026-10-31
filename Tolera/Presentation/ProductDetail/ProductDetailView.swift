import SwiftUI

/// Bir alternatif ürüne dokununca NavigationStack üzerinden açılan, geri dönülebilir
/// yeni ekran. Mevcut sonuç ekranını değiştirmez, üzerine yığılır.
struct ProductDetailView: View {
    let viewModel: ProductDetailViewModel

    var body: some View {
        ScrollView {
            ProductResultView(result: viewModel.result)
                .padding()
        }
        .navigationTitle(viewModel.result.product.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
