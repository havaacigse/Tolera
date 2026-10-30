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
    ContentView(
        searchViewModel: SearchViewModel(
            productRepository: ProductRepositoryImpl(),
            profileRepository: UserProfileRepositoryImpl(),
            checkProductUseCase: CheckProductUseCase()
        ),
        profileViewModel: ProfileViewModel(repository: UserProfileRepositoryImpl())
    )
}
