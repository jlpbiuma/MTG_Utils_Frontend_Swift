//
//  mtg_utilsApp.swift
//  mtg-utils
//
//  Created by Jose Luis on 06/09/2026.
//

import SwiftUI

@main
struct mtg_utilsApp: App {
    @State private var appStore = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appStore)
                .preferredColorScheme(.dark)
                .tint(.mtgAmber)
        }
    }
}

// MARK: - Root gate (login first)

struct RootView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        if appStore.session.active {
            ContentView()
        } else {
            LoginView()
        }
    }
}