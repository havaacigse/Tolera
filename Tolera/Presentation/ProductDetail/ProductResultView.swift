import SwiftUI

/// Bir ürünün kontrol sonucunu (banner, başlık, "neden" açıklaması, içindekiler) gösteren
/// paylaşılan görünüm. Hem ana arama ekranında hem de alternatif ürün detay ekranında kullanılır.
struct ProductResultView: View {
    let result: ProductCheckResult

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            banner
            productHeader
            details
            disclaimerNote
        }
    }

    private var banner: some View {
        let info = bannerInfo
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

    private var bannerInfo: (emoji: String, message: String, color: Color) {
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

    private var productHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let imageURL = result.product.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
            }

            Text(result.product.name)
                .font(.headline)

            if let brand = result.product.brand {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !result.detectedFromIngredients.isEmpty {
                Text("İçindekiler listesinden tespit edildi")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            whyExplanationSection

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

    @ViewBuilder
    private var whyExplanationSection: some View {
        let relevantAllergens = result.matchedAllergens.union(result.matchedTraces)
            .sorted(by: { $0.displayName < $1.displayName })

        if !relevantAllergens.isEmpty || !result.matchedCustomTerms.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Neden bu sonuç?")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(relevantAllergens) { allergen in
                    whyRow(
                        icon: allergen.emoji,
                        name: allergen.displayName,
                        reason: result.allergenReasons[allergen] ?? ""
                    )
                }

                ForEach(result.matchedCustomTerms.sorted(), id: \.self) { term in
                    whyRow(icon: "🔸", name: term, reason: "eşleşen kelime")
                }
            }
        }
    }

    private func whyRow(icon: String, name: String, reason: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(icon)
            Text(name)
                .font(.caption)
            Spacer()
            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var disclaimerNote: some View {
        Text("Bu sonuç bilgi amaçlıdır. Ciddi alerjin varsa ambalaj etiketini mutlaka kontrol et.")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
