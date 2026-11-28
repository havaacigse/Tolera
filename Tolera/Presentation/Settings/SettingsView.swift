import SwiftData
import SwiftUI

/// "Ayarlar ve hakkında" ekranı: sorumluluk reddi, veri kaynağı, sonuçların nasıl
/// belirlendiğine dair bilgilendirme ve "Tüm verilerimi sil". Profil ekranındaki dişli
/// simgesinden açılır; silme mantığı (`viewModel.deleteAllData()`, `onAllDataDeleted()`)
/// aynen `ProfileView`'dan taşındı — bkz. `ProfileViewModel.deleteAllData`,
/// `DeleteAllUserDataUseCase`, `RootViewModel.allDataDeleted`.
struct SettingsView: View {
    // Sabit (adaptif olmayan) bir marka rengi — başlıklarda ve linkte kasıtlı olarak hep
    // aynı tonda kalır. Kart/arka plan rengi İSE buraya hiç sabitlenmiyor: `.listStyle(
    // .insetGrouped)` zaten açık modda beyaz kart + #F2F2F7'ye çok yakın bir gri arka plan,
    // karanlık modda da kendi uygun koyu tonlarını otomatik veriyor — projenin diğer
    // ekranlarındaki gibi (bkz. ProfileView, ProductResultView) sabit renk yerine sisteme
    // bırakılıyor. Önceki sürüm `.listRowBackground(Color.white)` ile kartı sabit beyaza
    // zorluyordu; metinler ise `.foregroundStyle(.secondary)` (karanlık modda AÇIK renge
    // dönen, adaptif bir renk) kullandığından karanlık modda açık-gri-üzerine-beyaz gibi
    // okunaksız bir kombinasyon oluşuyordu.
    private let accentColor = Color(red: 0.184, green: 0.478, blue: 0.341) // #2F7A57

    let viewModel: ProfileViewModel
    let onAllDataDeleted: () -> Void

    @State private var isConfirmingDeleteAllData = false

    var body: some View {
        List {
            Section {
                bodyText(disclaimerText)
            } header: {
                Text("Sorumluluk")
                    .foregroundStyle(accentColor)
            }

            Section {
                bodyText(dataSourceText)

                Link(destination: URL(string: "https://world.openfoodfacts.org")!) {
                    Text("openfoodfacts.org")
                        .font(.footnote)
                }
                .tint(accentColor)
            } header: {
                Text("Veri kaynağı")
                    .foregroundStyle(accentColor)
            }

            Section {
                bodyText(howResultsAreDeterminedText)
            } header: {
                Text("Sonuçlar nasıl belirleniyor")
                    .foregroundStyle(accentColor)
            }

            Section {
                Button("Tüm verilerimi sil", role: .destructive) {
                    isConfirmingDeleteAllData = true
                }
                .foregroundStyle(.red)
            } header: {
                Text("Verilerim")
                    .foregroundStyle(accentColor)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Ayarlar ve Hakkında")
        .confirmationDialog(
            "Alerji profilin, okuttuğun ürünlerin bilgileri ve tarama geçmişin bu cihazdan kalıcı olarak silinir. Bu işlem geri alınamaz.",
            isPresented: $isConfirmingDeleteAllData,
            titleVisibility: .visible
        ) {
            Button("Tüm verilerimi sil", role: .destructive) {
                viewModel.deleteAllData()
                onAllDataDeleted()
            }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    /// Uzun gövde metinleri için ortak stil. `.fixedSize(horizontal: false, vertical: true)`
    /// satır sayısını sınırlamaz — metin ne kadar uzun olursa olsun satırın dikey olarak
    /// kesilmeden tamamen büyümesini garanti eder.
    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var disclaimerText: String {
        "Tolera tıbbi tavsiye vermez. Burada gösterilen sonuçlar yalnızca bilgi amaçlıdır ve ürünün kendi ambalaj etiketinin yerini tutmaz. Ciddi bir alerjin veya hassasiyetin varsa, satın almadan önce ürünün ambalajındaki içindekiler listesini her zaman kendin kontrol et."
    }

    private var dataSourceText: String {
        "Ürün bilgileri (içindekiler, alerjenler, görseller) Open Food Facts topluluk veritabanından alınır. Bu veri, gönüllüler tarafından girildiğinden hatalı veya eksik olabilir. Open Food Facts verisi Open Database License (ODbL) ile lisanslıdır. Ürün veritabanında yoksa, içindekiler metni çektiğin fotoğraftan cihaz üzerinde okunur; okuma hataları olabileceğinden sonuç daha temkinli verilir."
    }

    private var howResultsAreDeterminedText: String {
        "Tolera, ürünün içindekiler metnini önceden tanımlı bir alerjen terimleri listesiyle karşılaştırır; bu işlem kural tabanlıdır, tahmine dayalı bir yapay zeka değildir. Bir alerjenin kesin içerik mi yoksa eser miktarda/çapraz bulaşma ihtimali mi olduğu belirsizse, sistem her zaman daha temkinli olan sonucu seçer. \"Dikkat\" sonucu, o alerjenin üründe eser miktarda ya da çapraz bulaşma yoluyla bulunabileceği anlamına gelir, kesin içerik anlamına gelmez. Ciddi alerjin varsa bu ürünü tüketmemen önerilir. İçindekiler metni okunamadıysa, metin anlaşılamayan bir dildeyse veya hassasiyet profilin boşsa, sonuç hiçbir zaman \"Uygun\" olarak gösterilmez; bu durumlarda \"Bilinmiyor\" sonucu verilir."
    }
}

#Preview {
    let modelContainer = try! ModelContainer(
        for: SavedIngredientsTextModel.self, ScanHistoryEntryModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NavigationStack {
        SettingsView(
            viewModel: ProfileViewModel(
                repository: UserProfileRepositoryImpl(),
                deleteAllUserDataUseCase: DeleteAllUserDataUseCase(
                    savedIngredientsTextRepository: SavedIngredientsTextRepositoryImpl(modelContainer: modelContainer),
                    scanHistoryRepository: ScanHistoryRepositoryImpl(modelContainer: modelContainer),
                    userProfileRepository: UserProfileRepositoryImpl()
                )
            ),
            onAllDataDeleted: {}
        )
    }
}
