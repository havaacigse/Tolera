//
//  ContentView.swift
//  Tolera
//
//  Created by HAVVA on 28.10.2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    enum Tab {
        case search
        case profile
    }

    let searchViewModel: SearchViewModel
    let profileViewModel: ProfileViewModel
    @State private var selectedTab: Tab = .search

    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView(viewModel: searchViewModel, onGoToProfile: { selectedTab = .profile })
                .tabItem {
                    Label("Ara", systemImage: "barcode.viewfinder")
                }
                .tag(Tab.search)

            ProfileView(viewModel: profileViewModel)
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
    }
}

#Preview {
    let productRepository = ProductRepositoryImpl()
    let checkProductUseCase = CheckProductUseCase()
    let modelContainer = try! ModelContainer(
        for: SavedIngredientsTextModel.self, ScanHistoryEntryModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ContentView(
        searchViewModel: SearchViewModel(
            productRepository: productRepository,
            profileRepository: UserProfileRepositoryImpl(),
            checkProductUseCase: checkProductUseCase,
            findAlternativesUseCase: FindAlternativesUseCase(
                productRepository: productRepository,
                checkProductUseCase: checkProductUseCase
            ),
            textRecognitionService: VisionTextRecognitionService(),
            savedIngredientsTextRepository: SavedIngredientsTextRepositoryImpl(modelContainer: modelContainer)
        ),
        profileViewModel: ProfileViewModel(repository: UserProfileRepositoryImpl())
    )
}
