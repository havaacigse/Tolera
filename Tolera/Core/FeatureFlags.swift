import Foundation

/// Geçici olarak açılıp kapatılabilen özellik anahtarları.
enum FeatureFlags {
    /// Uygun olmayan (unsafe/caution) bir üründe "Bunun yerine deneyebileceklerin"
    /// alternatif önerisi bölümü. false iken ne arama ağ isteği yapılır ne de bölüm
    /// gösterilir. Tekrar açmak için sadece bunu `true` yapmak yeterli.
    static let alternativeSuggestionsEnabled = false
}
