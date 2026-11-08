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

    init() {
        findAlternativesUseCase = FindAlternativesUseCase(
            productRepository: productRepository,
            checkProductUseCase: checkProductUseCase
        )

        // Kalıcı depo bozuk/erişilemez olursa uygulama açılışta çökmesin diye bellek-içi
        // depoya düşülür. Bu depolar henüz hiçbir ekrana bağlı olmadığından veri kaybı
        // şu an kullanıcıya görünmez; tek amaç açılış çökmesini önlemek.
        let modelContainer: ModelContainer
        if let persistent = try? ModelContainer(for: SavedIngredientsTextModel.self, ScanHistoryEntryModel.self) {
            modelContainer = persistent
        } else {
            modelContainer = try! ModelContainer(
                for: SavedIngredientsTextModel.self, ScanHistoryEntryModel.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        let modelContext = modelContainer.mainContext
        savedIngredientsTextRepository = SavedIngredientsTextRepositoryImpl(modelContext: modelContext)
        scanHistoryRepository = ScanHistoryRepositoryImpl(modelContext: modelContext)
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
                    textRecognitionService: textRecognitionService
                ),
                profileViewModel: ProfileViewModel(repository: profileRepository)
            )
        }
    }
}
