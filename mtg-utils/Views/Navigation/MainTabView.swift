import SwiftUI

// MARK: - Main Tab & Navigation Bar

struct MainTabView: View {
    @Environment(AppStore.self) private var appStore
    @State private var selectedTab: AppTab = .decks
    @State private var visitedTabs: Set<AppTab> = [.decks]
    @State private var isScannerPresented = false
    @State private var isAccountPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab contents
            TabView(selection: $selectedTab) {
                NavigationStack {
                    Group {
                        if visitedTabs.contains(.decks) { DecksListView() }
                    }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                accountButton
                            }
                        }
                }
                .tag(AppTab.decks)

                NavigationStack {
                    Group {
                        if visitedTabs.contains(.collection) { CollectionView() }
                    }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                accountButton
                            }
                        }
                }
                .tag(AppTab.collection)

                NavigationStack {
                    Group {
                        if visitedTabs.contains(.buy) { BuyView() }
                    }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                accountButton
                            }
                        }
                }
                .tag(AppTab.buy)

                NavigationStack {
                    Group {
                        if visitedTabs.contains(.prices) { PricesView() }
                    }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                accountButton
                            }
                        }
                }
                .tag(AppTab.prices)
            }
            .toolbar(.hidden, for: .tabBar)
            .onChange(of: selectedTab) { _, tab in visitedTabs.insert(tab) }

            // Custom bottom navigation bar
            customBottomBar
        }
        .sheet(isPresented: $isScannerPresented) {
            NavigationStack {
                CardScannerView(appStore: appStore)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") {
                                isScannerPresented = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $isAccountPresented) {
            NavigationStack {
                AccountView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") {
                                isAccountPresented = false
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Account Button for Top Bar

    private var accountButton: some View {
        Button {
            isAccountPresented = true
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(appStore.session.active ? Color.mtgAmber : Color.mtgTextSecondary)
        }
        .accessibilityLabel("Mi cuenta")
    }

    // MARK: - Custom Bottom Bar

    private var customBottomBar: some View {
        HStack(spacing: 0) {
            // Tab 1: Mazos
            tabButton(
                tab: .decks,
                title: "Mazos",
                icon: "rectangle.stack.fill"
            )

            // Tab 2: Colección
            tabButton(
                tab: .collection,
                title: "Colección",
                icon: "square.grid.2x2"
            )

            // Center: Escanear (Modal Action)
            centerScanButton

            // Tab 3: Comprar
            tabButton(
                tab: .buy,
                title: "Comprar",
                icon: "cart.fill"
            )

            // Tab 4: Precios
            tabButton(
                tab: .prices,
                title: "Precios",
                icon: "chart.line.uptrend.xyaxis"
            )
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Color.mtgSurface
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(tab: AppTab, title: String, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: selectedTab == tab ? .bold : .regular))
                Text(title)
                    .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
            }
            .foregroundStyle(selectedTab == tab ? Color.mtgAmber : Color.mtgTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    private var centerScanButton: some View {
        Button {
            isScannerPresented = true
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.mtgAmber, Color.mtgAmberDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.mtgAmber.opacity(0.35), radius: 6, x: 0, y: 3)

                    Image(systemName: "viewfinder")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.black)
                }

                Text("Escanear")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.mtgAmber)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Escanear carta")
    }
}
