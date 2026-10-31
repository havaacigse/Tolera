//
//  ContentView.swift
//  Tolera
//
//  Created by HAVVA on 28.10.2026.
//

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
    ContentView(
        searchViewModel: SearchViewModel(
            productRepository: productRepository,
            profileRepository: UserProfileRepositoryImpl(),
            checkProductUseCase: checkProductUseCase,
            findAlternativesUseCase: FindAlternativesUseCase(
                productRepository: productRepository,
                checkProductUseCase: checkProductUseCase
            )
        ),
        profileViewModel: ProfileViewModel(repository: UserProfileRepositoryImpl())
    )
}
