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
                .preferredColorScheme(appStore.settings.theme.colorScheme)
                .tint(.mtgAmber)
        }
    }
}

// MARK: - Root gate (login first)

struct RootView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        Group {
            if !appStore.isLaunchReady {
                LaunchView()
            } else if appStore.session.active {
                ContentView()
            } else {
                LoginView()
            }
        }
        .task {
            await appStore.finishLaunching()
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            Color.mtgBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 164, height: 164)
                    .accessibilityHidden(true)

                Text("MTG Utils")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.mtgText)

                ProgressView()
                    .tint(.mtgAmber)
                    .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MTG Utils se está iniciando")
    }
}
