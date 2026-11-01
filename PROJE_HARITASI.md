# Tolera — Proje Haritası

Bu dosya koda dokunmadan çıkarılmış bir envanterdir. 2026-11-01 tarihli kod
taban üzerinden otomatik oluşturulmuştur; ileride dosya eklenip
çıkarıldığında elle güncellenmesi gerekir.

**Toplam:** 73 Swift dosyası (uygulama: 55, testler: 16, UI testleri: 2),
~5.391 satır (uygulama: 3.609, testler: 1.708, UI testleri: 74).

---

## 1. Tüm Swift dosyaları (klasörlere göre gruplu)

### App (47 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/App/RootView.swift` | 30 | Onboarding tamamlanmışsa `ContentView`'ı, tamamlanmamışsa `OnboardingView`'ı gösterir. |
| `Tolera/App/RootViewModel.swift` | 17 | Onboarding'in tamamlanıp tamamlanmadığını profil deposundan okuyup tutar. |

### Kök (104 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/ToleraApp.swift` | 51 | Uygulamanın giriş noktası ve asıl kompozisyon kökü; tüm somut repository/use case'leri ve `ModelContainer`'ı kurar. |
| `Tolera/ContentView.swift` | 53 | "Ara" ve "Profil" sekmelerini barındıran `TabView`; kendi `#Preview`'ında da bağımlılıkları elle kurar. |

### Core (312 satır) — katman bağımsız saf yardımcılar

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Core/AllergenCardGrid.swift` | 69 | Profil ekranında alerjen seçimi için kart grid'i (View). |
| `Tolera/Core/FlowLayout.swift` | 45 | Değişken genişlikli etiketleri satıra sığdığı kadar yan yana dizen `Layout`. |
| `Tolera/Core/IngredientsSectionExtractor.swift` | 82 | OCR metninden "içindekiler" bölümünü (başlık sonrası, besin tablosu öncesi) ayıklar ve başlık bulunup bulunmadığını raporlar. |
| `Tolera/Core/IngredientsTextCleaner.swift` | 14 | OFF'tan gelen içindekiler metnindeki vurgu karakterlerini (`_`, `*`, `[]`, `&quot;`) temizler. |
| `Tolera/Core/OCRNonLatinWordFilter.swift` | 42 | OCR metninde sadece Latin dışı alfabeyle yazılmış kelimeleri (satırın tamamını değil) ayıklar. |
| `Tolera/Core/OCRTextCleaner.swift` | 20 | OCR metnindeki satır sonlarını ve tireyle bölünmüş kelimeleri birleştirir. |
| `Tolera/Core/TurkishWordMatcher.swift` | 40 | Türkçe karakter toleranslı (ı/i, ğ/g vb.) kelime başı/tam kelime eşleştirme. |

### Domain/Entities (226 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Domain/Entities/Allergen.swift` | 83 | 14 zorunlu alerjenin enum'ı; görünen ad, emoji ve OFF etiketi eşlemesi. |
| `Tolera/Domain/Entities/IngredientDetectionResult.swift` | 14 | `IngredientAllergenDetector`'ın çıktısı (contains/mayContain/dil/neden). |
| `Tolera/Domain/Entities/Product.swift` | 20 | Barkod, ad, marka, görsel, içindekiler, alerjen/eser, kategori, tür taşıyan ürün modeli. |
| `Tolera/Domain/Entities/ProductCheckResult.swift` | 26 | Bir kontrolün tam sonucu (durum, eşleşen alerjenler, nedenler, özel bayraklar). |
| `Tolera/Domain/Entities/SavedIngredientsText.swift` | 21 | Barkod hafızasındaki tek bir OCR metni kaydı. |
| `Tolera/Domain/Entities/ScanHistoryEntry.swift` | 62 | Bir tarama geçmişi kaydı + kaynağını belirten `ScanSource` enum'ı. |

### Domain/Repositories (66 satır) — protokoller

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Domain/Repositories/ProductRepository.swift` | 14 | Barkodla ürün çekme ve kategoriye göre ürün arama protokolü. |
| `Tolera/Domain/Repositories/SavedIngredientsTextRepository.swift` | 9 | Barkod hafızası okuma/yazma protokolü. |
| `Tolera/Domain/Repositories/ScanHistoryRepository.swift` | 10 | Tarama geçmişi okuma/yazma protokolü. |
| `Tolera/Domain/Repositories/TextRecognitionService.swift` | 18 | OCR (metin tanıma) protokolü. |
| `Tolera/Domain/Repositories/UserProfileRepository.swift` | 15 | Kullanıcı profili (alerjen/ad/özel terim/onboarding) okuma/yazma protokolü. |

### Domain/UseCases (823 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Domain/UseCases/AllergenKeywords.swift` | 101 | Dedektörün kullandığı tüm anahtar kelime/istisna/izinli kelime sözlükleri. |
| `Tolera/Domain/UseCases/CheckIngredientsTextUseCase.swift` | 41 | OCR metnini temizleyip `CheckProductUseCase`'e devreder, başlık kuralını uygular. |
| `Tolera/Domain/UseCases/CheckProductUseCase.swift` | 117 | Bir `Product`'ı kullanıcı profiliyle karşılaştırıp `ProductCheckResult` üretir (ana iş kuralı). |
| `Tolera/Domain/UseCases/CustomTermDetector.swift` | 13 | Kullanıcının kendi eklediği özel terimleri metinde arar. |
| `Tolera/Domain/UseCases/FindAlternativesUseCase.swift` | 83 | Uygun olmayan bir ürüne aynı kategoriden güvenli alternatif önerir. |
| `Tolera/Domain/UseCases/IngredientAllergenDetector.swift` | 365 | Metinden alerjen tespiti yapan kural tabanlı, deterministik ana dedektör. |
| `Tolera/Domain/UseCases/IngredientsScanRedirectPolicy.swift` | 28 | Barkod taramasından sonra OCR ekranına otomatik yönlendirme kararını veren saf fonksiyon. |
| `Tolera/Domain/UseCases/MissingIngredientsHeadingRule.swift` | 29 | "İçindekiler başlığı yoksa sonuç asla safe olamaz" kuralı. |
| `Tolera/Domain/UseCases/RecheckScanHistoryEntryUseCase.swift` | 46 | Bir geçmiş kaydını güncel profille yeniden hesaplar. |

### Data/DTOs (78 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Data/DTOs/OFFCategorySearchResponseDTO.swift` | 13 | OFF kategori arama API cevabının (sadece barkod listesi) decode modeli. |
| `Tolera/Data/DTOs/OFFProductResponseDTO.swift` | 65 | OFF ürün detayı API cevabının decode modeli + `Product`'a dönüşüm. |

### Data/Local (291 satır) — SwiftData

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Data/Local/SavedIngredientsTextModel.swift` | 73 | `SavedIngredientsText`'in SwiftData `@Model` karşılığı + domain dönüşümü. |
| `Tolera/Data/Local/SavedIngredientsTextRepositoryImpl.swift` | 45 | `SavedIngredientsTextRepository`'nin SwiftData implementasyonu. |
| `Tolera/Data/Local/ScanHistoryEntryModel.swift` | 134 | `ScanHistoryEntry`'nin SwiftData `@Model` karşılığı + enum kodlama/kod açma. |
| `Tolera/Data/Local/ScanHistoryRepositoryImpl.swift` | 39 | `ScanHistoryRepository`'nin SwiftData implementasyonu. |

### Data/Remote (125 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Data/Remote/OpenFoodFactsSearchService.swift` | 60 | `search.openfoodfacts.org` üzerinden kategoriye göre barkod arar. |
| `Tolera/Data/Remote/OpenFoodFactsService.swift` | 65 | `world.openfoodfacts.org` / `world.openbeautyfacts.org` üzerinden barkodla ürün detayı çeker. |

### Data/Repositories (185 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Data/Repositories/ProductRepositoryImpl.swift` | 121 | `ProductRepository`'nin OFF/OBF + arama servisini birleştiren implementasyonu. |
| `Tolera/Data/Repositories/UserProfileRepositoryImpl.swift` | 64 | `UserProfileRepository`'nin `UserDefaults` implementasyonu. |

### Data/Vision (68 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Data/Vision/VisionTextRecognitionService.swift` | 68 | `TextRecognitionService`'in Apple Vision implementasyonu (dil seçimi dahil). |

### Presentation/IngredientsScan (306 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Presentation/IngredientsScan/CameraCaptureView.swift` | 52 | Tek kare fotoğraf çekimi için `UIImagePickerController` sarmalayıcısı. |
| `Tolera/Presentation/IngredientsScan/IngredientsScanView.swift` | 158 | "İçindekileri Fotoğrafla" ekranı: kaynak seçimi, metin düzenleme, sonuç. |
| `Tolera/Presentation/IngredientsScan/IngredientsScanViewModel.swift` | 96 | OCR'ı çalıştırır, metni filtreler/ayıklar, kontrolü tetikler. |

### Presentation/Onboarding (134 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Presentation/Onboarding/OnboardingView.swift` | 94 | Hoş geldin → ad → alerjen seçimi adımlarını gösteren ilk kurulum ekranı. |
| `Tolera/Presentation/Onboarding/OnboardingViewModel.swift` | 40 | Onboarding adımlarının durumunu ve kaydetme işlemini yönetir. |

### Presentation/ProductDetail (192 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Presentation/ProductDetail/ProductDetailView.swift` | 16 | Alternatif üründe dokununca NavigationStack üzerinde açılan detay ekranı. |
| `Tolera/Presentation/ProductDetail/ProductDetailViewModel.swift` | 23 | Seçilen alternatif ürünü güncel profille yeniden hesaplar. |
| `Tolera/Presentation/ProductDetail/ProductResultView.swift` | 153 | Banner/başlık/neden/içindekiler bölümlerini gösteren paylaşılan sonuç görünümü. |

### Presentation/Profile (171 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Presentation/Profile/ProfileView.swift` | 119 | Ad, alerjen seçimi ve özel terimlerin düzenlendiği profil ekranı. |
| `Tolera/Presentation/Profile/ProfileViewModel.swift` | 52 | Profil verilerini okuyup kaydeder. |

### Presentation/Scanner (481 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `Tolera/Presentation/Scanner/BarcodeScannerView.swift` | 61 | `DataScannerViewController` ile sürekli barkod tarama sarmalayıcısı. |
| `Tolera/Presentation/Scanner/SearchView.swift` | 290 | Ana "Ara" ekranı: tarama, sonuç, alternatifler, OCR'a geçiş bağlantıları. |
| `Tolera/Presentation/Scanner/SearchViewModel.swift` | 130 | Barkod aramasını, sonucu ve alternatifleri yönetir; alt view model'leri üretir. |

### ToleraTests (1.708 satır)

Bkz. bölüm 5 (test sayılarıyla birlikte).

### ToleraUITests (74 satır)

| Dosya | Satır | Görevi |
|---|---|---|
| `ToleraUITests/ToleraUITests.swift` | 41 | Xcode şablonundan gelen, henüz doldurulmamış örnek UI testi + launch performansı. |
| `ToleraUITests/ToleraUITestsLaunchTests.swift` | 33 | Xcode şablonundan gelen, açılış ekranı ekran görüntüsü alan örnek test. |

---

## 2. Framework'ler

### Dosya başına import

| Framework | Kullanan dosyalar |
|---|---|
| `Foundation` | Core, Domain, Data katmanlarındaki neredeyse tüm saf Swift dosyaları (DTO, entity, use case, repository impl). |
| `SwiftUI` | Tüm View dosyaları (`App`, `ContentView`, `Presentation/*View.swift`, `Core/AllergenCardGrid`, `Core/FlowLayout`), ayrıca `BarcodeScannerView`, `CameraCaptureView` (UIViewControllerRepresentable). |
| `Observation` | Tüm `@Observable` ViewModel'ler (`RootViewModel`, `SearchViewModel`, `ProfileViewModel`, `OnboardingViewModel`, `ProductDetailViewModel`, `IngredientsScanViewModel`). |
| `SwiftData` | `Tolera/ToleraApp.swift`, `Data/Local/*` (4 dosya). |
| `UIKit` | `Data/Vision/VisionTextRecognitionService.swift` (`UIImage`), `Presentation/IngredientsScan/CameraCaptureView.swift` (`UIImagePickerController`). |
| `Vision` | `Data/Vision/VisionTextRecognitionService.swift` (OCR: `VNRecognizeTextRequest`). |
| `VisionKit` | `Presentation/Scanner/BarcodeScannerView.swift` (`DataScannerViewController` ile barkod tarama). |
| `NaturalLanguage` | `Domain/UseCases/IngredientAllergenDetector.swift` (`NLLanguageRecognizer` ile dil tespiti). |
| `PhotosUI` | `Presentation/IngredientsScan/IngredientsScanView.swift` (`PhotosPicker`, simülatörde test için). |
| `Testing` (Swift Testing) | Tüm `ToleraTests/*.swift` dosyaları. |
| `XCTest` | `ToleraUITests/*.swift` (UI testleri, Swift Testing henüz UI testlerinde kullanılmıyor — Xcode şablonu kalıntısı). |

### Kullanım amaçları (özet)

- **Vision**: Ambalaj fotoğrafından OCR (`VNRecognizeTextRequest`, `.accurate` seviye, desteklenen dile göre tr-TR/en-US seçimi).
- **VisionKit**: Kamerayla sürekli barkod tarama (`DataScannerViewController`).
- **UIKit**: Tek kare fotoğraf çekimi (`UIImagePickerController`) ve OCR'a girdi olan `UIImage`.
- **PhotosUI**: Simülatörde (kamerasız) test için fotoğraf kütüphanesinden seçim; ek izin gerektirmez.
- **NaturalLanguage**: İçindekiler metninin Türkçe/İngilizce olup olmadığını tespit etmek (kısa metinlerde devre dışı, bilinen kelime kontrolüne düşer).
- **SwiftData**: Barkod hafızası ve tarama geçmişinin cihazda kalıcı saklanması.
- **Observation**: SwiftUI View'ların ViewModel'leri gözlemlemesi (`@Observable` makrosu).
- **Testing**: Birim testleri (`@Test`, `#expect`).

---

## 3. Üçüncü parti paket

**Yok.** `Package.swift`, `Package.resolved`, `Podfile`, `Cartfile` dosyaları
projede bulunmuyor; `.pbxproj` içinde `XCRemoteSwiftPackageReference` /
`XCLocalSwiftPackageReference` referansı yok. Tüm bağımlılıklar Apple'ın
sistem framework'leri.

---

## 4. Katmanlar arası bağımlılıklar

### Protokoller ve kimler kullanıyor

| Protokol | Tanımlandığı yer | Somut implementasyon | Kullanan ViewModel/UseCase |
|---|---|---|---|
| `ProductRepository` | `Domain/Repositories/ProductRepository.swift` | `ProductRepositoryImpl` | `SearchViewModel`, `FindAlternativesUseCase` |
| `UserProfileRepository` | `Domain/Repositories/UserProfileRepository.swift` | `UserProfileRepositoryImpl` | `RootViewModel`, `OnboardingViewModel`, `ProfileViewModel`, `SearchViewModel`, `IngredientsScanViewModel`, `ProductDetailViewModel` |
| `TextRecognitionService` | `Domain/Repositories/TextRecognitionService.swift` | `VisionTextRecognitionService` | `SearchViewModel` (fabrika için), `IngredientsScanViewModel` |
| `SavedIngredientsTextRepository` | `Domain/Repositories/SavedIngredientsTextRepository.swift` | `SavedIngredientsTextRepositoryImpl` | *(henüz hiçbir ViewModel kullanmıyor — bkz. not aşağıda)* |
| `ScanHistoryRepository` | `Domain/Repositories/ScanHistoryRepository.swift` | `ScanHistoryRepositoryImpl` | *(henüz hiçbir ViewModel kullanmıyor — bkz. not aşağıda)* |

> **Not:** `SavedIngredientsTextRepository`/`ScanHistoryRepository` ve bunların
> SwiftData implementasyonları (ve `RecheckScanHistoryEntryUseCase`,
> `IngredientsScanRedirectPolicy`, `MissingIngredientsHeadingRule`) şu an
> sadece `ToleraApp.swift`'te örnekleniyor/test ediliyor; henüz hiçbir
> `SearchViewModel`/`ProfileViewModel` akışına bağlanmadı (barkod hafızası ve
> tarama geçmişi özellikleri yarım — Domain+Data katmanı hazır, Presentation
> katmanı henüz yok).

### Somut sınıfların oluşturulduğu yerler

**Üretim kompozisyon kökü — `Tolera/ToleraApp.swift`:**
- `ProductRepositoryImpl()` → `productRepository`
- `UserProfileRepositoryImpl()` → `profileRepository`
- `CheckProductUseCase()` → `checkProductUseCase`
- `FindAlternativesUseCase(productRepository:checkProductUseCase:)` → `findAlternativesUseCase`
- `VisionTextRecognitionService()` → `textRecognitionService`
- `ModelContainer(for: SavedIngredientsTextModel.self, ScanHistoryEntryModel.self)` → `modelContainer` (kalıcı, cihaz diskinde; in-memory değil)
- `SavedIngredientsTextRepositoryImpl(modelContext:)` → `savedIngredientsTextRepository`
- `ScanHistoryRepositoryImpl(modelContext:)` → `scanHistoryRepository`

Bunlar `RootView` → `SearchViewModel`/`ProfileViewModel`/`OnboardingViewModel`/`RootViewModel`'e enjekte edilir.

**Ayrıca SwiftUI `#Preview` bloklarında** (üretim akışının parçası değil,
sadece canvas/önizleme için) aynı somut sınıflar tekrar elle kuruluyor:
`ContentView.swift`, `Presentation/Scanner/SearchView.swift`,
`Presentation/Profile/ProfileView.swift`,
`Presentation/Onboarding/OnboardingView.swift`,
`Presentation/IngredientsScan/IngredientsScanView.swift`.

### ViewModel → bağımlılık tablosu

| ViewModel/UseCase | Bağımlılıkları |
|---|---|
| `SearchViewModel` | `ProductRepository`, `UserProfileRepository`, `CheckProductUseCase`, `FindAlternativesUseCase`, `TextRecognitionService` |
| `ProductDetailViewModel` | `CheckProductUseCase`, `UserProfileRepository` (init'te bir kere kullanılır, saklanmaz) |
| `IngredientsScanViewModel` | `TextRecognitionService`, `CheckIngredientsTextUseCase`, `UserProfileRepository` |
| `ProfileViewModel` | `UserProfileRepository` |
| `OnboardingViewModel` | `UserProfileRepository` |
| `RootViewModel` | `UserProfileRepository` |
| `CheckProductUseCase` | `IngredientAllergenDetector`, `CustomTermDetector` |
| `CheckIngredientsTextUseCase` | `CheckProductUseCase`, (dolaylı) `OCRTextCleaner`, `MissingIngredientsHeadingRule` |
| `FindAlternativesUseCase` | `ProductRepository`, `CheckProductUseCase` |
| `RecheckScanHistoryEntryUseCase` | `CheckProductUseCase`, (dolaylı) `MissingIngredientsHeadingRule` |
| `ProductRepositoryImpl` | `OpenFoodFactsService` (x2: food + beauty), `OpenFoodFactsSearchService` |

---

## 5. Test dosyaları

Toplam **155 `@Test`** (Swift Testing) + **3 XCTest fonksiyonu** (UI testleri).

| Dosya | Test sayısı | Kapsadığı |
|---|---|---|
| `IngredientAllergenDetectorTests.swift` | 65 | Ana dedektör (anahtar kelime eşleşmesi, eser miktar, istisnalar, dil tespiti). |
| `CheckProductUseCaseTests.swift` | 18 | Ürün kontrolünün genel iş kuralı (durum hesaplama, OFF+metin birleştirme). |
| `CheckIngredientsTextUseCaseTests.swift` | 9 | OCR metni kontrolü + başlık bulunamama kuralı. |
| `FindAlternativesUseCaseTests.swift` | 9 | Alternatif ürün önerisi (kategori yükselme, limit, hata ayrımı). |
| `IngredientsSectionExtractorTests.swift` | 9 | İçindekiler bölümü ayıklama + başlık bulma. |
| `CustomTermDetectorTests.swift` | 5 | Kullanıcının özel terimlerinin eşleşmesi. |
| `OCRTextCleanerTests.swift` | 5 | OCR satır sonu/tire birleştirme. |
| `RecheckScanHistoryEntryUseCaseTests.swift` | 5 | Geçmiş kaydının güncel profille yeniden hesaplanması. |
| `SavedIngredientsTextRepositoryImplTests.swift` | 5 | Barkod hafızası SwiftData implementasyonu (kayıt/bulma/üzerine yazma/silme). |
| `ScanHistoryRepositoryImplTests.swift` | 5 | Tarama geçmişi SwiftData implementasyonu (kayıt/sıralama/silme/tümünü temizleme). |
| `IngredientsScanRedirectPolicyTests.swift` | 7 | OCR'a otomatik yönlendirme kararı (7 senaryo). |
| `MissingIngredientsHeadingRuleTests.swift` | 4 | Başlık bulunamama kuralının kendisi. |
| `OCRNonLatinWordFilterTests.swift` | 4 | Latin dışı kelime filtresi. |
| `VisionTextRecognitionServiceTests.swift` | 3 | OCR dil seçimi (tr-TR destekleniyorsa onu, yoksa en-US). |
| `GoldenSetEvaluationTests.swift` | 1 | Gerçek ürün verisiyle (bkz. `ToleraTests/EvaluationData/golden_set.json`) dedektör/OFF karşılaştırması — tek test içinde özet rapor üretir. |
| `ToleraTests.swift` | 1 | Xcode şablonundan gelen boş örnek test. |
| **ToleraUITests/ToleraUITests.swift** | 2 (XCTest) | Boş örnek UI testi + açılış performans ölçümü. |
| **ToleraUITests/ToleraUITestsLaunchTests.swift** | 1 (XCTest) | Açılış ekranı görüntüsü alan örnek test. |

Hepsi birim/entegrasyon seviyesinde; gerçek cihaz/simülatör ekran testi
(uçtan uca) otomasyonu yok — bu tür testler konuşma geçmişinde kullanıcı
tarafından elle yapılıyor.

---

## 6. Ağ istekleri ve cihazda saklanan veriler

### Ağ istekleri (hepsi `URLSession`, DTO → domain dönüşümüyle)

| İstek | Host | Ne zaman | Dosya |
|---|---|---|---|
| Ürün detayı (gıda) | `world.openfoodfacts.org/api/v2/product/{barkod}` | Her barkod taramasında/elle girişte | `OpenFoodFactsService` (barkod = gıda varsayılır, önce denenir) |
| Ürün detayı (kozmetik) | `world.openbeautyfacts.org/api/v2/product/{barkod}` | Gıda isteği 404 dönerse otomatik fallback | `OpenFoodFactsService` (ikinci bir örnek, farklı `baseURL` ile) |
| Kategori arama (barkod listesi) | `search.openfoodfacts.org/search` | Sonuç unsafe/caution çıkıp alternatif aranırken, kategori başına en fazla 1 kez (oturum içi bellekte önbellekli) | `OpenFoodFactsSearchService` |

- İstekler `GET`, özel bir API anahtarı yok; `User-Agent: Tolera/0.1 (iOS; bitirme projesi)` gönderiliyor.
- `ProductRepositoryImpl` kategori sonuçlarını sadece **bellekte** (oturum boyunca, `categoryCache` sözlüğü) önbellekliyor; kalıcı değil.
- Gemini/AllergenAnalyzer (CLAUDE.md'de bahsedilen LLM entegrasyonu) kod tabanında **henüz implemente edilmemiş** — hiçbir dosyada bu isimler geçmiyor.

### Cihazda saklanan veriler

**`UserDefaults` (`UserProfileRepositoryImpl`):**

| Anahtar | İçerik |
|---|---|
| `user.allergens` | Kullanıcının seçtiği alerjenlerin `rawValue` dizisi. |
| `user.name` | Kullanıcının adı (boşsa anahtar hiç yazılmaz/silinir). |
| `user.onboardingCompleted` | Onboarding'in tamamlanıp tamamlanmadığı (Bool). |
| `user.customTerms` | Kullanıcının eklediği özel terimler (küçük harfe çevrilmiş, tekilleştirilmiş). |

**SwiftData (kalıcı, varsayılan diskte depo — `ToleraApp.swift`'te kurulan `ModelContainer`, in-memory değil):**

| Model | İçerik | Durum |
|---|---|---|
| `SavedIngredientsTextModel` | Barkod başına tek OCR metni kaydı (marka, görsel, kategori, metin, başlık bulundu mu, tarih). | Domain/Data hazır; henüz hiçbir View/ViewModel bu depoya yazmıyor/okumuyor (bağlanmamış). |
| `ScanHistoryEntryModel` | Her taramanın değişmez kaydı (barkod, ürün adı, marka, görsel, metin, alerjen/eser, kategori, tür, kaynak, anlık durum, tarih). | Aynı şekilde henüz bağlanmamış. |

**Diğer:** Klasörde `Keychain`, `CoreData`, `@AppStorage` veya dosya tabanlı
(`FileManager`) bir saklama kullanılmıyor. `ToleraTests/EvaluationData/golden_set.json`
sadece test hedefine gömülü, statik bir değerlendirme verisidir (çalışma
zamanında cihaza yazılmaz).

### İzinler (Info.plist / build ayarları)

Kamera izni `INFOPLIST_KEY_NSCameraUsageDescription` build ayarıyla
tanımlanmış ama **açıklama metni şu an boş** (`Tolera.xcodeproj/project.pbxproj`
içinde iki hedef konfigürasyonunda da `= ""`); `Tolera/Info.plist` ise
boş bir `dict` — gerçek izin metni başka bir yerde tanımlı değilse App
Store/TestFlight incelemesinde veya kamera isteğinde sorun çıkarabilir.
Fotoğraf kütüphanesi seçimi (`PhotosPicker`) ayrı bir izin gerektirmiyor.
Bu gözlem bilgi amaçlıdır, kod değiştirilmedi.
