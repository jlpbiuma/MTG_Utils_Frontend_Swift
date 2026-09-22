//
//  ContentView.swift
//  mtg-utils
//
//  Created by Jose Luis on 06/09/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environment(AppStore.demo)
        .preferredColorScheme(.dark)
}
