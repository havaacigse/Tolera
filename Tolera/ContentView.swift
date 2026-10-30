//
//  ContentView.swift
//  Tolera
//
//  Created by HAVVA on 28.10.2026.
//

import SwiftUI

struct ContentView: View {
    let searchViewModel: SearchViewModel
    let profileViewModel: ProfileViewModel

    var body: some View {
        TabView {
            SearchView(viewModel: searchViewModel)
                .tabItem {
                    Label("Ara", systemImage: "barcode.viewfinder")
                }

            ProfileView(viewModel: profileViewModel)
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
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
