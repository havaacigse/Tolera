//
//  ToleraApp.swift
//  Tolera
//
//  Created by HAVVA on 28.10.2026.
//

import SwiftData
import SwiftUI

@main
struct ToleraApp: App {
    private let productRepository: ProductRepository = ProductRepositoryImpl()
    private let profileRepository: UserProfileRepository = UserProfileRepositoryImpl()
    private let checkProductUseCase = CheckProductUseCase()
    private let findAlternativesUseCase: FindAlternativesUseCase
    private let textRecognitionService: TextRecognitionService = VisionTextRecognitionService()
    private let savedIngredientsTextRepository: SavedIngredientsTextRepository
    private let scanHistoryRepository: ScanHistoryRepository
    // Uygulamanın ömrü boyunca açıkça canlı tutulur: sadece init() içinde yerel
    // değişken olsaydı, context'i kullanan repository'ler container deallocate
    // olduktan sonra çökebilirdi (bkz. SavedIngredientsTextRepositoryImpl'deki not).
    private let modelContainer: ModelContainer

    init() {
        findAlternativesUseCase = FindAlternativesUseCase(
            productRepository: productRepository,
            checkProductUseCase: checkProductUseCase
        )

        // Kalıcı depo bozuk/erişilemez olursa uygulama açılışta çökmesin diye bellek-içi
        // depoya düşülür. Bu depolar henüz hiçbir ekrana bağlı olmadığından veri kaybı
        // şu an kullanıcıya görünmez; tek amaç açılış çökmesini önlemek.
        if let persistent = try? ModelContainer(for: SavedIngredientsTextModel.self, ScanHistoryEntryModel.self) {
            modelContainer = persistent
        } else {
            modelContainer = try! ModelContainer(
                for: SavedIngredientsTextModel.self, ScanHistoryEntryModel.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        savedIngredientsTextRepository = SavedIngredientsTextRepositoryImpl(modelContainer: modelContainer)
        scanHistoryRepository = ScanHistoryRepositoryImpl(modelContainer: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                rootViewModel: RootViewModel(repository: profileRepository),
                onboardingViewModel: OnboardingViewModel(repository: profileRepository),
                searchViewModel: SearchViewModel(
                    productRepository: productRepository,
                    profileRepository: profileRepository,
                    checkProductUseCase: checkProductUseCase,
                    findAlternativesUseCase: findAlternativesUseCase,
                    textRecognitionService: textRecognitionService,
                    savedIngredientsTextRepository: savedIngredientsTextRepository,
                    scanHistoryRepository: scanHistoryRepository
                ),
                profileViewModel: ProfileViewModel(repository: profileRepository)
            )
        }
    }
}
