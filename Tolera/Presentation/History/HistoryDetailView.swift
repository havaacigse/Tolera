import SwiftUI

/// Tek bir geçmiş kaydının detayı. YENİ bir analiz yapmaz; `row.result` (satırda zaten
/// güncel profille hesaplanmış `ProductCheckResult`) kullanılır. `row.entry.snapshotStatus`
/// (tarama anının donmuş görüntüsü) bu View'da da hiçbir yerde kullanılmaz — bkz. `HistoryView`.
struct HistoryDetailView: View {
    let row: HistoryRow
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    var body: some View {
        Form {
            Section("Ürün") {
                LabeledContent("Ürün adı", value: HistoryFormatting.displayName(for: row.entry))
                if let brand = row.entry.brand, !brand.isEmpty {
                    LabeledContent("Marka", value: brand)
                }
                if let barcode = row.entry.barcode, !barcode.isEmpty {
                    LabeledContent("Barkod", value: barcode)
                }
                LabeledContent("Durum", value: HistoryFormatting.statusLabelText(for: row.result.status))
                LabeledContent("Kaynak", value: HistoryFormatting.sourceText(for: row.entry.source))
                LabeledContent("Tarama tarihi", value: row.entry.scannedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if row.statusChanged {
                Section {
                    Text("Bu ürün taradığın sırada farklı bir sonuç vermişti. Profilin değiştiği için güncel sonuç gösteriliyor.")
                        .foregroundStyle(.orange)
                }
            }

            if let unknownReason = HistoryFormatting.unknownReasonText(for: row.result) {
                Section("Neden bilinmiyor?") {
                    Text(unknownReason)
                }
            }

            let allergenReasons = HistoryFormatting.matchedAllergenReasons(for: row.result)
            if !allergenReasons.isEmpty {
                Section("Alerjenler") {
                    ForEach(allergenReasons) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.allergen.displayName).font(.headline)
                            Text(item.reason).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            let traceReasons = HistoryFormatting.matchedTraceReasons(for: row.result)
            if !traceReasons.isEmpty {
                Section("Eser Miktar (İz)") {
                    ForEach(traceReasons) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.allergen.displayName).font(.headline)
                            Text(item.reason).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !row.result.matchedCustomTerms.isEmpty {
                Section("Özel Terimler") {
                    ForEach(row.result.matchedCustomTerms, id: \.self) { term in
                        Text(term)
                    }
                }
            }

            if row.entry.source == .ocrPhoto,
               let ingredientsText = row.entry.ingredientsText,
               !ingredientsText.isEmpty {
                Section {
                    DisclosureGroup("İçindekiler metnini gör") {
                        Text(ingredientsText)
                    }
                }
            }

            Section {
                Button("Bu kaydı sil", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .navigationTitle(HistoryFormatting.displayName(for: row.entry))
        .confirmationDialog(
            "Bu kayıt silinsin mi?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Vazgeç", role: .cancel) {}
        }
    }
}
