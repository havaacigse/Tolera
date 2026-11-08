import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    @State private var isShowingScanner = false
    @State private var isShowingManualEntry = false
    private let onGoToProfile: () -> Void

    init(viewModel: SearchViewModel, onGoToProfile: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onGoToProfile = onGoToProfile
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scanSection
                    manualEntrySection
                    ingredientsScanLink

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else if viewModel.isProductNotFound {
                        productNotFoundNotice
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else if let result = viewModel.result {
                        resultContent(for: result)
                    }
                }
                .padding()
            }
            .navigationTitle("Ara")
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(viewModel: viewModel.makeDetailViewModel(for: product))
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView { code in
                isShowingScanner = false
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.handleScannedBarcode(code)
            }
            .ignoresSafeArea()
        }
    }

    private var scanSection: some View {
        Group {
            if BarcodeScannerView.isAvailable {
                Button {
                    isShowingScanner = true
                } label: {
                    Label("Barkod Tara", systemImage: "barcode.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "camera.metering.unknown")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Bu cihazda kamera ile barkod tarama kullanılamıyor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Barkodu elle gir") {
                withAnimation {
                    isShowingManualEntry.toggle()
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if isShowingManualEntry {
                HStack {
                    TextField("Barkod", text: $viewModel.barcode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)

                    Button("Ara") {
                        viewModel.search()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private func resultContent(for result: ProductCheckResult) -> some View {
        if result.isProfileEmpty {
            emptyProfileNotice
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ProductResultView(result: result)

                if FeatureFlags.alternativeSuggestionsEnabled,
                   result.status == .unsafe || result.status == .caution {
                    alternativesSection
                } else if result.status == .unknown && !result.isCosmeticNotSupported {
                    unknownResultIngredientsScanNotice
                }
            }
        }
    }

    private var unknownResultIngredientsScanNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bu ürün için içindekiler bilgisi yok. Ambalaj fotoğrafından kontrol edebilirsin.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ingredientsScanLink
        }
    }

    private var ingredientsScanLink: some View {
        NavigationLink {
            IngredientsScanView(viewModel: viewModel.makeIngredientsScanViewModel())
        } label: {
            Label("İçindekileri Fotoğrafla", systemImage: "camera.viewfinder")
                .font(.footnote)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bunun yerine deneyebileceklerin")
                .font(.headline)

            if viewModel.isLoadingAlternatives {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if viewModel.alternativesLoadFailed {
                Text("Alternatifler şu an yüklenemedi.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let alternatives = viewModel.alternatives {
                if alternatives.isEmpty {
                    Text("Bu kategoride senin için uygun ve içerik bilgisi olan bir alternatif bulamadık.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(alternatives) { alternative in
                        NavigationLink(value: alternative) {
                            alternativeCard(for: alternative)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func alternativeCard(for product: Product) -> some View {
        HStack(spacing: 12) {
            if let imageURL = product.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.secondary.opacity(0.1)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if let brand = product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Seçtiğin hassasiyetlerin hiçbirini içermiyor.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyProfileNotice: some View {
        VStack(spacing: 12) {
            Text("🧑‍⚕️")
                .font(.system(size: 40))
            Text("Önce hassasiyetlerini seç")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("Hangi alerjenlere dikkat etmen gerektiğini bilmeden ürünleri senin için değerlendiremeyiz.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Profile Git", action: onGoToProfile)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var productNotFoundNotice: some View {
        VStack(spacing: 14) {
            Text("🔍")
                .font(.system(size: 40))
            Text("Bu ürün veritabanında bulunamadı.")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button("Tekrar Tara") {
                    isShowingScanner = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                Button("Barkodu Elle Gir") {
                    withAnimation { isShowingManualEntry = true }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Link(destination: URL(string: "https://world.openfoodfacts.org")!) {
                    Text("Ürünü Open Food Facts'e Ekle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                ingredientsScanLink
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    let productRepository = ProductRepositoryImpl()
    let checkProductUseCase = CheckProductUseCase()
    SearchView(
        viewModel: SearchViewModel(
            productRepository: productRepository,
            profileRepository: UserProfileRepositoryImpl(),
            checkProductUseCase: checkProductUseCase,
            findAlternativesUseCase: FindAlternativesUseCase(
                productRepository: productRepository,
                checkProductUseCase: checkProductUseCase
            ),
            textRecognitionService: VisionTextRecognitionService()
        ),
        onGoToProfile: {}
    )
}
