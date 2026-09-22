import SwiftUI

// MARK: - Buy View Container (Priorities & Wants)

struct BuyView: View {
    @State private var selectedSubTab: BuySubTab = .priorities

    enum BuySubTab: String, CaseIterable, Identifiable {
        case priorities = "Prioridades"
        case wants = "Wants"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Segmented Control
            Picker("Comprar", selection: $selectedSubTab) {
                ForEach(BuySubTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(Color.mtgSurface)

            // Sub-tab view
            Group {
                switch selectedSubTab {
                case .priorities:
                    PrioritiesView()
                case .wants:
                    WantsView()
                }
            }
        }
        .navigationTitle(selectedSubTab.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
