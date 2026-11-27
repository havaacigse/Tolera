import Foundation
import Testing
@testable import Tolera

struct CheckIngredientsTextUseCaseTests {
    @Test func ocrTarziMetindeTireIleBolunenKelimeDogruAnalizEdilir() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "BUĞDAY UNU (GLUTEN), Şeker. FIN-\nDIK İÇEREBİLİR."

        let result = useCase.execute(rawText: rawText, userAllergens: [.gluten, .nuts], customTerms: [], headingFound: true)

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.gluten))
        #expect(result.matchedTraces.contains(.nuts))
    }

    /// OCR'da nokta kaybolup "eser miktar" uyarısı önceki cümleyle (virgülle) birleşirse,
    /// hangi kelimenin eser miktar hangisinin içerik olduğu belirsizleşir; temkinli ilke
    /// gereği (contains > mayContain) ikisi de içerik sayılır — mayContain'e düşürülmez.
    @Test func noktalamaKaybolanOcrMetnindeTemkinliIlkeIkisiniDeIcerikSayar() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "BUĞDAY UNU (GLUTEN), Şeker, FINDIK İÇEREBİLİR."

        let result = useCase.execute(rawText: rawText, userAllergens: [.gluten, .nuts], customTerms: [], headingFound: true)

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.gluten))
        #expect(result.matchedAllergens.contains(.nuts))
        #expect(result.matchedTraces.isEmpty)
    }

    @Test func bosProfilIleIsProfileEmptyDoner() {
        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(rawText: "şeker, su", userAllergens: [], customTerms: [], headingFound: true)

        #expect(result.isProfileEmpty)
    }

    @Test func uretilenUrunKategorisizVeBarkodsuzdur() {
        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(rawText: "su, şeker", userAllergens: [.milk], customTerms: [], headingFound: true)

        #expect(result.product.categories.isEmpty)
        #expect(result.product.barcode.isEmpty)
    }

    /// Barkod hafızasından (SavedIngredientsTextRepository) servis edilen bir sonuç için
    /// barkod/marka/görsel/kategori bilgisi de taşınabilmeli (ör. alternatif önerisi ileride
    /// bu bilgiyi kullanabilsin).
    @Test func barkodVeOffBilgisiVerilirseUrunTasinir() {
        let useCase = CheckIngredientsTextUseCase()
        let imageURL = URL(string: "https://example.com/image.jpg")!
        let result = useCase.execute(
            rawText: "su, şeker",
            userAllergens: [.milk],
            customTerms: [],
            headingFound: true,
            barcode: "123",
            brand: "Marka",
            imageURL: imageURL,
            categories: ["yogurts"]
        )

        #expect(result.product.barcode == "123")
        #expect(result.product.brand == "Marka")
        #expect(result.product.imageURL == imageURL)
        #expect(result.product.categories == ["yogurts"])
    }

    @Test func ozelTerimIcerenMetindeEslesir() {
        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(rawText: "mısır nişastası, su", userAllergens: [], customTerms: ["mısır"], headingFound: true)

        #expect(result.status == .unsafe)
        #expect(result.matchedCustomTerms == ["mısır"])
    }

    // MARK: - Başlık bulunamazsa sonuç asla "safe" olamaz (temkinli ilke)

    /// Gerçek cihaz hatası: OCR içindekiler yerine üretim yeri/adres metnini okudu ve
    /// hiçbir alerjen kelimesi eşleşmediği için sonuç "safe" dönmüştü. "İçindekiler"
    /// başlığı bulunamadığında bu artık mümkün değil: sonuç "unknown"a çevrilir.
    @Test func basliksizUretimYeriMetninSuTAlerjisindeSafeDegilUnknownDoner() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "Üretim yeri: Konya, Türkiye. Net 500 g. Son tüketim tarihi..."

        let result = useCase.execute(rawText: rawText, userAllergens: [.milk], customTerms: [], headingFound: false)

        #expect(result.status == .unknown)
        #expect(result.isMissingIngredientsHeading)
    }

    /// Başlık bulunamasa da metinde gerçekten alerjen kelimesi eşleştiyse (ör. "yoğurt")
    /// bu geçerliliğini korur; temkinli ilke sadece "safe"i engeller, "unsafe"i gizlemez.
    @Test func basliksizMetindeAlerjenEslesirseUnsafeKalir() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "Süzme yoğurt, net 500 g"

        let result = useCase.execute(rawText: rawText, userAllergens: [.milk], customTerms: [], headingFound: false)

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.milk))
        #expect(!result.isMissingIngredientsHeading)
    }

    @Test func basliklaBulunanMetindeAlerjenEslesirseUnsafeDoner() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "İçindekiler: pastörize inek sütü, yoğurt kültürü"

        let result = useCase.execute(rawText: rawText, userAllergens: [.milk], customTerms: [], headingFound: true)

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.milk))
    }

    /// Başlık bulunduğunda ve içinde hiç alerjen yoksa "safe" geçerliliğini korur —
    /// kısıtlama sadece başlık BULUNAMADIĞINDA devreye girer.
    @Test func basliklaBulunanAlerjensizMetinSafeKalir() {
        let useCase = CheckIngredientsTextUseCase()
        let rawText = "İçindekiler: su, şeker, tuz"

        let result = useCase.execute(rawText: rawText, userAllergens: [.milk], customTerms: [], headingFound: true)

        #expect(result.status == .safe)
        #expect(!result.isMissingIngredientsHeading)
    }

    // MARK: - Uyarı cümleleri: içindekiler penceresi DIŞINDaki alerjen uyarıları

    /// Gerçek cihaz riski: kullanıcı ekranda sadece ayıklanmış (kesilmiş) metni görüp onu
    /// düzenlese bile, ham OCR metninin tamamındaki uyarı taraması yine çalışmalı — yoksa
    /// besin tablosundan sonraki "X içerebilir" uyarısı sessizce kaybolur.
    @Test func besinTablosundanSonrakiUyariKullaniciDuzenlenmisMetindeOlmasaDaTespitEdilir() {
        let useCase = CheckIngredientsTextUseCase()
        let fullRawText = "İçindekiler: şeker, kakao. Besin değerleri: Enerji 500 kcal. Alerjen uyarısı: Fındık içerebilir."
        // Kullanıcı ekranda sadece ayıklanmış kısmı görüyor ve düzenliyor; uyarı bunun içinde YOK.
        let editedExtractedText = "şeker, kakao"

        let result = useCase.execute(
            rawText: editedExtractedText,
            userAllergens: [.nuts],
            customTerms: [],
            headingFound: true,
            fullRawText: fullRawText
        )

        #expect(result.status == .caution)
        #expect(result.matchedTraces.contains(.nuts))
        #expect(result.allergenReasons[.nuts]?.contains("Etiketin başka bir yerinde") == true)
    }

    /// "X içerir" gibi daha kesin bir ifade, içindekiler listesinden ÖNCE yazılsa da
    /// contains (sadece eser miktar değil) olarak sayılır.
    @Test func baslikOncesiKesinUyariContainsOlarakSayilir() {
        let useCase = CheckIngredientsTextUseCase()
        let fullRawText = "Alerjen uyarısı: Süt içerir. İçindekiler: şeker, kakao."

        let result = useCase.execute(
            rawText: "şeker, kakao",
            userAllergens: [.milk],
            customTerms: [],
            headingFound: true,
            fullRawText: fullRawText
        )

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.milk))
    }

    /// `fullRawText` verilmezse (ör. barkod hafızasından yeniden hesaplama) uyarı taraması
    /// hiç yapılmaz — geriye dönük uyumluluk, davranış değişmez.
    @Test func fullRawTextVerilmezseUyariTaramasiYapilmaz() {
        let useCase = CheckIngredientsTextUseCase()
        let result = useCase.execute(rawText: "şeker, kakao", userAllergens: [.nuts], customTerms: [], headingFound: true)

        #expect(result.status == .safe)
    }

    /// Birleştirme her zaman en temkinli sonucu almalı: içindekiler metnindeki "glutensiz
    /// yulaf" çapraz bulaşma uyarısı (eser miktar, mayContain) ile ham metindeki "gluten
    /// içerir" uyarısı (içerik, contains) birleştiğinde, daha temkinli (contains) kazanmalı —
    /// "içindekiler metni OFF etiketine üstün gelir" kuralı bunu EZMEMELİ.
    @Test func birlestirmeEnTemkinliSonucuAlirUyariIcindekilerinEserMiktarSinyalinizEzmez() {
        let useCase = CheckIngredientsTextUseCase()
        let fullRawText = "İçindekiler: glutensiz yulaf. Alerjen uyarısı: gluten içerir."

        let result = useCase.execute(
            rawText: "glutensiz yulaf",
            userAllergens: [.gluten],
            customTerms: [],
            headingFound: true,
            fullRawText: fullRawText
        )

        #expect(result.status == .unsafe)
        #expect(result.matchedAllergens.contains(.gluten))
        #expect(!result.matchedTraces.contains(.gluten))
    }
}
