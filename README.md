# Tolera

An iOS app that scans a product's barcode (or its ingredients label) and flags whether it's safe for the user based on their own allergen/sensitivity profile.

## Status

🎓 Graduation project — **in active development**, not feature-complete.

## Current Features

- **Barcode scanning**: scans EAN-13/EAN-8/UPC-E barcodes (VisionKit) or manual entry, looks up the product via the [Open Food Facts](https://world.openfoodfacts.org) API.
- **Rule-based allergen detection**: deterministic, keyword-based matching against the 14 allergens that are mandatory to declare under Turkish/EU food law, plus user-defined custom terms. No LLM is involved in the safety decision itself.
- **Cautious-by-design result model**: the result is always one of `unsafe` / `caution` / `safe` / `unknown`, and the app never defaults to "safe" when it isn't sure — e.g. when the ingredients text is missing, in an unrecognized language, the user's profile is empty, or the product is a cosmetic (not yet supported, see below).
- **Ingredients-photo scanning (OCR)**: for products with no or incomplete data on Open Food Facts, the user can photograph the ingredients label; the text is read with Apple's Vision framework, shown for the user to review/edit, and run through the same rule engine.
- **Profile & onboarding**: name, allergen selection, and free-text custom sensitivity terms — all stored only on-device (no account, no server).
- Includes unit tests and a set of real product labels used to check the allergen detection rules.

## Planned Features

- Alternative product suggestions (same-category, safe alternatives for an unsafe/caution result) — the underlying logic already exists in the codebase but is currently disabled behind a feature flag while it's being refined.
- Cosmetics category support (INCI ingredient lists are a different problem from food labels).
- Multi-language support beyond Turkish and English.

## Tech Stack

- Swift, SwiftUI, `@Observable` (Observation framework)
- Vision (OCR) & VisionKit (barcode scanning)
- NaturalLanguage (language detection for OCR text)
- SwiftData (local persistence layer; present in the codebase, not yet wired into the UI)
- Swift Testing & XCTest
- No third-party dependencies (no SPM/CocoaPods packages)
- [Open Food Facts](https://world.openfoodfacts.org) / Open Beauty Facts REST APIs

## Architecture

MVVM + a light Clean Architecture split, under `Tolera/`:

```
App/            Root navigation & onboarding routing
Domain/         Entities, Repository protocols, UseCases — no framework imports
Data/           Remote (OFF API), Local (SwiftData), Vision, DTOs, Repository implementations
Presentation/   SwiftUI views + ViewModels, grouped by screen (Scanner, ProductDetail, Profile, IngredientsScan)
Core/           Framework-independent helpers shared across layers
```

`Domain` has no knowledge of SwiftData, Vision, or networking — those live in `Data`, mapped through the Repository protocols.

## Setup

```bash
git clone <repo-url>
open Tolera.xcodeproj
```

No API key is required to run the current features.

---

### Türkçe Özet

Tolera, barkod okutularak veya ambalaj fotoğrafı çekilerek bir ürünün kullanıcının alerjen/hassasiyet profiline uygun olup olmadığını kontrol eden bir iOS uygulamasıdır. Alerjen tespiti kural tabanlı ve deterministiktir; belirsiz durumlarda asla "güvenli" sonucuna varmaz. Şu an bitirme projesi kapsamında geliştirilmeye devam etmektedir; alternatif ürün önerisi, kozmetik ürün desteği ve çok dillilik gibi özellikler planlanmış ancak henüz tamamlanmamıştır.
