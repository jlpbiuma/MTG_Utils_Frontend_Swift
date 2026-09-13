import SwiftUI
import Observation

/// Preferences shared by the app and persisted locally on the device.
@Observable
@MainActor
final class AppSettings {
    enum Theme: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return "Sistema"
            case .light: return "Claro"
            case .dark: return "Oscuro"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    private enum Keys {
        static let theme = "mtg.settings.theme"
        static let priceProvider = "mtg.settings.priceProvider"
    }

    var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    var priceProvider: PriceProvider {
        didSet { UserDefaults.standard.set(priceProvider.rawValue, forKey: Keys.priceProvider) }
    }

    init(defaults: UserDefaults = .standard) {
        theme = Theme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        // Cardmarket is deliberately the first-run default.
        priceProvider = PriceProvider(rawValue: defaults.string(forKey: Keys.priceProvider) ?? "") ?? .cardmarket
    }
}
