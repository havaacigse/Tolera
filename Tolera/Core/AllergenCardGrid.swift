import SwiftUI

struct AllergenCardGrid: View {
    private static let common: [Allergen] = [.gluten, .milk, .eggs, .peanuts, .nuts, .soybeans]
    private static let other: [Allergen] = Allergen.allCases.filter { !common.contains($0) }

    let selected: Set<Allergen>
    let onToggle: (Allergen) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            section(title: "En yaygın", allergens: Self.common)
            section(title: "Diğer", allergens: Self.other)
        }
    }

    private func section(title: String, allergens: [Allergen]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                ForEach(allergens) { allergen in
                    AllergenCard(allergen: allergen, isSelected: selected.contains(allergen)) {
                        onToggle(allergen)
                    }
                }
            }
        }
    }
}

private struct AllergenCard: View {
    let allergen: Allergen
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Text(allergen.emoji)
                        .font(.system(size: 32))
                        .frame(maxWidth: .infinity)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Color.accentColor)
                    }
                }

                Text(allergen.displayName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AllergenCardGrid(selected: [.milk, .nuts]) { _ in }
        .padding()
}
