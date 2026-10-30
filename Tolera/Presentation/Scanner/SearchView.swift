import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    @State private var isShowingScanner = false
    @State private var isShowingManualEntry = false

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scanSection
                    manualEntrySection

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
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
        VStack(alignment: .leading, spacing: 20) {
            banner(for: result)
            productHeader(for: result.product)
            details(for: result)
        }
    }

    private func banner(for result: ProductCheckResult) -> some View {
        let info = bannerInfo(for: result)
        return VStack(spacing: 8) {
            Text(info.emoji)
                .font(.system(size: 48))
            Text(info.message)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(info.color.opacity(0.15))
        .foregroundStyle(info.color)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func bannerInfo(for result: ProductCheckResult) -> (emoji: String, message: String, color: Color) {
        if result.isCosmeticNotSupported {
            return ("🧴", "Bu bir kozmetik ürün. Kozmetik ürün kontrolü yakında eklenecek.", .gray)
        }

        switch result.status {
        case .unsafe:
            let names = (result.matchedAllergens.map(\.displayName) + result.matchedCustomTerms)
                .sorted()
                .joined(separator: ", ")
            return ("🚫", "Senin için uygun değil — \(names) içeriyor", .red)
        case .caution:
            let names = result.matchedTraces.map(\.displayName).sorted().joined(separator: ", ")
            return ("⚠️", "Dikkat — eser miktarda \(names) içerebilir", .orange)
        case .safe:
            return ("✅", "Senin için uygun görünüyor", .green)
        case .unknown:
            return ("❓", "Yeterli bilgi yok — etiketi kontrol et", .gray)
        }
    }

    private func productHeader(for product: Product) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let imageURL = product.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
            }

            Text(product.name)
                .font(.headline)

            if let brand = product.brand {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func details(for result: ProductCheckResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !result.detectedFromIngredients.isEmpty {
                Text("İçindekiler listesinden tespit edildi")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            if !result.matchedAllergens.isEmpty {
                allergenRow(title: "Eşleşen alerjenler", allergens: result.matchedAllergens)
            }

            if !result.matchedTraces.isEmpty {
                allergenRow(title: "Eser miktar uyarıları", allergens: result.matchedTraces)
            }

            if !result.matchedCustomTerms.isEmpty {
                customTermRow(title: "Eşleşen diğer hassasiyetler", terms: result.matchedCustomTerms)
            }

            if let ingredients = result.product.ingredientsText, !ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("İçindekiler")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(ingredients)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func allergenRow(title: String, allergens: Set<Allergen>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(allergens.sorted(by: { $0.displayName < $1.displayName })) { allergen in
                Text("\(allergen.emoji) \(allergen.displayName)")
                    .font(.caption)
            }
        }
    }

    private func customTermRow(title: String, terms: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(terms.sorted(), id: \.self) { term in
                Text(term)
                    .font(.caption)
            }
        }
    }
}

#Preview {
    SearchView(viewModel: SearchViewModel(
        productRepository: ProductRepositoryImpl(),
        profileRepository: UserProfileRepositoryImpl(),
        checkProductUseCase: CheckProductUseCase()
    ))
}
