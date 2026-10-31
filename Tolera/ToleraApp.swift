//
//  ToleraApp.swift
//  Tolera
//
//  Created by HAVVA on 28.10.2026.
//

import SwiftUI

@main
struct ToleraApp: App {
    private let productRepository: ProductRepository = ProductRepositoryImpl()
    private let profileRepository: UserProfileRepository = UserProfileRepositoryImpl()
    private let checkProductUseCase = CheckProductUseCase()
    private let findAlternativesUseCase: FindAlternativesUseCase
    private let textRecognitionService: TextRecognitionService = VisionTextRecognitionService()

    init() {
        findAlternativesUseCase = FindAlternativesUseCase(
            productRepository: productRepository,
            checkProductUseCase: checkProductUseCase
        )
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
