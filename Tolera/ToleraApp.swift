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

    var body: some Scene {
        WindowGroup {
            RootView(
                rootViewModel: RootViewModel(repository: profileRepository),
                onboardingViewModel: OnboardingViewModel(repository: profileRepository),
                searchViewModel: SearchViewModel(
                    productRepository: productRepository,
                    profileRepository: profileRepository,
                    checkProductUseCase: checkProductUseCase
                ),
                profileViewModel: ProfileViewModel(repository: profileRepository)
            )
        }
    }
}
