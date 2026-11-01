import Foundation

/// Barkod başına tek OCR metni hafızası. Bkz. `SavedIngredientsText`.
protocol SavedIngredientsTextRepository {
    func find(barcode: String) -> SavedIngredientsText?
    func save(_ record: SavedIngredientsText)
    func delete(barcode: String)
    func all() -> [SavedIngredientsText]
}
