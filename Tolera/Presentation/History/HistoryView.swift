import SwiftUI

/// Tarama geçmişi ekranı. Durum HER ZAMAN `row.result.status`'tan (güncel profille yeniden
/// hesaplanmış sonuç) gösterilir; `row.entry.snapshotStatus` (tarama anının donmuş
/// görüntüsü) bu View'da hiçbir yerde kullanılmaz — bkz. `HistoryViewModel`.
struct HistoryView: View {
    @State private var viewModel: HistoryViewModel
    @State private var isConfirmingDeleteAll = false

    init(viewModel: HistoryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Geçmiş")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Tümünü sil", role: .destructive) {
                            isConfirmingDeleteAll = true
                        }
                        .disabled(viewModel.dayGroups.isEmpty)
                    }
                }
                .confirmationDialog(
                    "Tüm tarama geçmişi silinsin mi?",
                    isPresented: $isConfirmingDeleteAll,
                    titleVisibility: .visible
                ) {
                    Button("Tümünü sil", role: .destructive) {
                        viewModel.deleteAll()
                    }
                    Button("Vazgeç", role: .cancel) {}
                }
        }
        .onAppear {
            viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.dayGroups.isEmpty {
            ContentUnavailableView("Henüz tarama yok", systemImage: "clock")
        } else {
            List {
                ForEach(viewModel.dayGroups) { group in
                    Section(HistoryFormatting.dayHeaderText(for: group.day)) {
                        ForEach(group.rows) { row in
                            NavigationLink {
                                HistoryDetailView(row: row, onDelete: { viewModel.delete(id: row.id) })
                            } label: {
                                HistoryRowContent(row: row)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.delete(id: row.id)
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Tek bir geçmiş satırının görünümü. Gösterilen durum metni `row.result.status`'tan gelir.
private struct HistoryRowContent: View {
    let row: HistoryRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(HistoryFormatting.displayName(for: row.entry))
                .font(.headline)

            HStack(spacing: 6) {
                Text(HistoryFormatting.statusLabelText(for: row.result.status))
                Text("·")
                Text(HistoryFormatting.sourceText(for: row.entry.source))
                Text("·")
                Text(row.entry.scannedAt.formatted(date: .omitted, time: .shortened))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if row.statusChanged {
                Text("Profilin değişti, sonuç güncellendi.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
