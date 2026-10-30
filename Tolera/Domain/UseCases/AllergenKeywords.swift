import Foundation

/// `IngredientAllergenDetector`'ın kullandığı tüm anahtar kelime, istisna ve izinli
/// kelime listeleri. Mantıktan ayrı tutulur ki sözlüğü güncellemek (yeni kelime
/// eklemek/çıkarmak) algoritmaya dokunmayı gerektirmesin.
enum AllergenKeywords {
    /// İstisnalar: anahtar kelimelerle yanlışlıkla çakışan ama alerjenle ilgisi olmayan
    /// ifadeler. Eşleşmeden önce metinden tamamen silinir.
    /// - "eggplant" → "egg" (yumurta) ile, "nutmeg" → gelecekte eklenebilecek "nut" ile çakışabilir.
    /// - "coconut" → "coconut milk" normalize edildikten sonra (ks. plantMilks) geriye kalan tek kelime.
    /// - "ekmek mayası" → maya demektir, gluten içermez; "ekmek" (bileşik yiyecek) ile çakışır.
    /// - "kekik" → baharattır; "kek" (bileşik yiyecek) kelimesinin öneki ile çakışır.
    static let exceptions = [
        "hindistan cevizi", "kakao yağı", "maltodekstrin", "maltitol", "maltoz",
        "eggplant", "nutmeg", "coconut", "ekmek mayası", "kekik"
    ]

    /// Ünsüz yumuşaması / özel durum: "Antep fıstığı/fıstıklı/fıstık" sert kabuklu
    /// yemiştir (pistachio), ama bare "fıstık" (peanuts) anahtar kelimesiyle çakışır.
    /// Bu yüzden genel aramadan önce ayrıca aranıp metinden çıkarılır.
    static let pistachioPhrases = ["antep fıstığı", "antep fıstıklı", "antep fıstık"]

    /// Bitkisel sütler dairy değildir: "X sütü"/"X milk" kalıbında sadece süt kısmı
    /// silinir, X (badem, soya, hindistan cevizi vb.) kalır ki kendi alerjeni olarak
    /// (ör. badem → sert kabuklu yemiş) doğru yakalansın.
    static let plantMilks: [(phrase: String, replacement: String)] = [
        ("badem sütü", "badem"),
        ("soya sütü", "soya"),
        ("yulaf sütü", "yulaf"),
        ("pirinç sütü", "pirinç"),
        ("hindistan cevizi sütü", "hindistan cevizi"),
        ("fındık sütü", "fındık"),
        ("coconut milk", "coconut")
    ]

    /// Her alerjen için aranacak anahtar kelimeler. Kelime başı eşleşmesi kullanıldığından
    /// (bkz. `TurkishWordMatcher`) çekimli haller de ("sütlü", "fındığı") otomatik yakalanır.
    static let keywordsByAllergen: [Allergen: [String]] = [
        .gluten: [
            "buğday", "arpa", "çavdar", "yulaf", "malt", "irmik", "irmiğ", "bulgur", "kepek", "kepeğ",
            "gluten", "galeta", "kuskus", "spelt", "wheat", "barley", "rye", "oat",
            // Bileşik yiyecekler: un/tahıl bazlı oldukları için gluten kaynağı sayılır.
            "makarna", "şehriye", "erişte", "yufka", "ekmek", "bisküvi", "kraker", "simit", "kek", "kadayıf"
        ],
        .milk: ["süt", "peynir", "tereyağ", "krema", "kaymak", "kaymağ", "yoğurt", "yoğurd", "laktoz", "kazein", "kazeinat", "peynir altı suyu", "whey", "milk"],
        .eggs: ["yumurta", "albümin", "egg", "mayonez"],
        .fish: ["balık", "balığ", "ançüez", "hamsi", "somon", "ton balığı", "fish"],
        .crustaceans: ["karides", "yengeç", "yengec", "ıstakoz", "kerevit", "shrimp", "crab"],
        .molluscs: ["midye", "kalamar", "ahtapot", "ahtapod", "istiridye", "mussel", "squid"],
        .peanuts: ["yer fıstığı", "yerfıstığı", "fıstık", "peanut"],
        .nuts: [
            "fındık", "fındığ", "badem", "ceviz", "kaju", "pikan", "makadamya",
            "hazelnut", "almond", "walnut", "cashew", "pistachio", "pecan", "macadamia",
            // Yaygın etiket ifadeleri: hepsi sert kabuklu yemiş kategorisine girer.
            "sert kabuklu meyve", "sert kabuklu yemiş", "kabuklu yemiş"
        ],
        .soybeans: ["soya", "soy"],
        .celery: ["kereviz", "celery"],
        .mustard: ["hardal", "mustard"],
        .sesame: ["susam", "tahin", "sesame"],
        .sulphites: ["sülfit", "sülfür dioksit", "metabisülfit", "e220", "e221", "e222", "e223", "e224", "e226", "e227", "e228", "sulphite", "sulfite"],
        .lupin: ["acı bakla", "lupin"]
    ]

    /// "eser miktarda"/"may contain" bir BAŞLANGIÇ ifadesidir: bu ifadeden önceki
    /// alerjenler gerçek içerik, sonrakiler eser miktar sayılır.
    static let leadingTraceMarkers = ["eser miktar", "may contain"]

    /// Başlangıç ifadesi yoksa ve sadece "içerebilir"/"bulunabilir" fiili varsa devreye girer.
    static let trailingTriggerPhrases = ["içerebilir", "bulunabilir"]

    /// Eser miktar cümlesinde fiil dışında sadece bu BAĞLAÇ kelimeleri varsa belirsizlik
    /// oluşturmaz (tam kelime eşleşmesi: "ve" kelimesi "venüs" gibi kelimelerle karışmasın).
    static let traceSentenceAllowedConnectorWords = ["ve", "ile", "veya", "bu", "iz", "may", "of", "and"]

    /// Eser miktar cümlesinde fiil dışında bu KATEGORİ kelimeleri de belirsizlik oluşturmaz.
    /// Kelime başı eşleşmesi kullanılır ki "ürünleri", "meyveler", "türevleri", "tohumu"
    /// gibi çoğul/ek almış halleri de karşılansın.
    static let traceSentenceAllowedCategoryWords = [
        "ürün", "eser", "miktar", "içerebilir", "bulunabilir", "düzeyde",
        "contain", "traces", "meyve", "türev", "tohum"
    ]

    /// "glutensiz yulaf/buğday": sadece "glutensiz"in hemen ardından gelen tahılı kapsar.
    /// Gerçek dünyada glutensiz yulaf/un ürünleri çapraz bulaşma riski taşıdığından gluten
    /// tamamen yok sayılmaz, eser miktar (mayContain) sayılır. Aynı cümledeki başka bir
    /// gluten kaynağı (ör. ayrı bir "buğday unu") bu kuraldan etkilenmez.
    static let glutenFreeCrossContaminationPhrases = ["glutensiz yulaf", "glutensiz buğday"]

    /// "gluten içermez/içermiyor" sadece kendi ifadesini etkiler (silinir); metindeki
    /// başka bir gluten kaynağı bu temizlikten sonra normal şekilde içerik sayılmaya devam eder.
    static let glutenNegationPhrases = ["gluten içermez", "gluten içermiyor"]

    /// Kısa metinlerde dil tespiti için: bunlardan en az biri geçmeli, yoksa metin
    /// Türkçe/İngilizce dışında bir dil olarak kabul edilir (bkz. `isSupportedLanguage`).
    static let commonGenericIngredientWords = [
        "su", "şeker", "tuz", "yağ", "sirke", "maya", "nişasta", "aroma",
        "water", "sugar", "salt", "oil"
    ]
}
