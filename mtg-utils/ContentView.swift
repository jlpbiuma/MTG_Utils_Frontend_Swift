//
//  ContentView.swift
//  mtg-utils
//
//  Created by Jose Luis on 06/09/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var appStore
    @State private var selectedTab: AppTab = .decks

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DecksListView()
            }
            .tabItem {
                Label("Mazos", systemImage: "rectangle.stack.fill")
            }
            .tag(AppTab.decks)

            NavigationStack {
                CollectionView()
            }
            .tabItem {
                Label("Colección", systemImage: "square.grid.2x2")
            }
            .tag(AppTab.collection)

            NavigationStack {
                CardScannerView(appStore: appStore)
            }
            .tabItem {
                Label("Escáner", systemImage: "viewfinder")
            }
            .tag(AppTab.scanner)

            NavigationStack {
                AccountView()
            }
            .tabItem {
                Label("Cuenta", systemImage: "person.crop.circle")
            }
            .tag(AppTab.account)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppStore.demo)
        .preferredColorScheme(.dark)
}
