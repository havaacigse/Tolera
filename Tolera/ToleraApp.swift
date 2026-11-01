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

        let modelContainer = try! ModelContainer(
            for: SavedIngredientsTextModel.self, ScanHistoryEntryModel.self
        )
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
