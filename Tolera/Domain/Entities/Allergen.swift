import Foundation

/// Türk Gıda Kodeksi'nde bildirimi zorunlu 14 alerjen.
enum Allergen: String, CaseIterable, Identifiable, Codable {
    case gluten
    case crustaceans
    case eggs
    case fish
    case peanuts
    case soybeans
    case milk
    case nuts
    case celery
    case mustard
    case sesame
    case sulphites
    case lupin
    case molluscs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gluten: return "Gluten İçeren Tahıllar"
        case .crustaceans: return "Kabuklu Deniz Ürünleri"
        case .eggs: return "Yumurta"
        case .fish: return "Balık"
        case .peanuts: return "Yer Fıstığı"
        case .soybeans: return "Soya Fasulyesi"
        case .milk: return "Süt ve Süt Ürünleri (Laktoz Dahil)"
        case .nuts: return "Sert Kabuklu Yemişler"
        case .celery: return "Kereviz"
        case .mustard: return "Hardal"
        case .sesame: return "Susam Tohumu"
        case .sulphites: return "Sülfür Dioksit ve Sülfitler"
        case .lupin: return "Acı bakla (lupin)"
        case .molluscs: return "Yumuşakçalar"
        }
    }

    var emoji: String {
        switch self {
        case .gluten: return "🌾"
        case .crustaceans: return "🦐"
        case .eggs: return "🥚"
        case .fish: return "🐟"
        case .peanuts: return "🥜"
        case .soybeans: return "🫘"
        case .milk: return "🥛"
        case .nuts: return "🌰"
        case .celery: return "🥬"
        case .mustard: return "🟡"
        case .sesame: return "⚪"
        case .sulphites: return "🧪"
        case .lupin: return "🌼"
        case .molluscs: return "🦑"
        }
    }

    /// Open Food Facts'in `allergens_tags` alanında kullandığı etiket.
    var offTag: String {
        switch self {
        case .gluten: return "en:gluten"
        case .crustaceans: return "en:crustaceans"
        case .eggs: return "en:eggs"
        case .fish: return "en:fish"
        case .peanuts: return "en:peanuts"
        case .soybeans: return "en:soybeans"
        case .milk: return "en:milk"
        case .nuts: return "en:nuts"
        case .celery: return "en:celery"
        case .mustard: return "en:mustard"
        case .sesame: return "en:sesame-seeds"
        case .sulphites: return "en:sulphur-dioxide-and-sulphites"
        case .lupin: return "en:lupin"
        case .molluscs: return "en:molluscs"
        }
    }

    static func from(offTag: String) -> Allergen? {
        Self.allCases.first { $0.offTag == offTag }
    }
}
