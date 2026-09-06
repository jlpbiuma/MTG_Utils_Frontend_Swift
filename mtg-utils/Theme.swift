import SwiftUI

// MARK: - MTG dark theme palette (slate + amber)
// Defined as ShapeStyle members so `.mtgX` resolves in `.foregroundStyle(...)`,
// `.fill(...)`, `.tint(...)` etc. (same mechanism as SwiftUI's `.red` / `.blue`).

extension ShapeStyle where Self == Color {
    static var mtgBackground: Color { Color(red: 0.03, green: 0.04, blue: 0.06) }      // slate-950
    static var mtgSurface: Color { Color(red: 0.09, green: 0.10, blue: 0.14) }         // slate-900
    static var mtgSurfaceElevated: Color { Color(red: 0.13, green: 0.15, blue: 0.20) } // slate-800
    static var mtgAmber: Color { Color(red: 0.96, green: 0.72, blue: 0.12) }           // amber-400
    static var mtgAmberDeep: Color { Color(red: 0.92, green: 0.62, blue: 0.05) }       // amber-500
    static var mtgGreen: Color { Color(red: 0.30, green: 0.78, blue: 0.35) }           // green-500
    static var mtgRed: Color { Color(red: 0.93, green: 0.34, blue: 0.31) }             // red-500
    static var mtgText: Color { Color(red: 0.93, green: 0.94, blue: 0.95) }            // slate-100
    static var mtgTextSecondary: Color { Color(red: 0.58, green: 0.61, blue: 0.68) }   // slate-400
}

// MARK: - Mana symbol colors

enum ManaSymbol: String {
    case white = "W"
    case blue = "U"
    case black = "B"
    case red = "R"
    case green = "G"
    case colorless = "C"
    case generic = "generic"
    case snow = "S"
    case energy = "E"
    case phyrexianWhite = "W/P"
    case phyrexianBlue = "U/P"
    case phyrexianBlack = "B/P"
    case phyrexianRed = "R/P"
    case phyrexianGreen = "G/P"

    var tint: Color {
        switch self {
        case .white, .phyrexianWhite: return Color(red: 0.96, green: 0.96, blue: 0.91)
        case .blue, .phyrexianBlue: return Color(red: 0.19, green: 0.55, blue: 0.85)
        case .black, .phyrexianBlack: return Color(red: 0.40, green: 0.42, blue: 0.47)
        case .red, .phyrexianRed: return Color(red: 0.91, green: 0.30, blue: 0.27)
        case .green, .phyrexianGreen: return Color(red: 0.24, green: 0.72, blue: 0.39)
        case .colorless: return Color(red: 0.66, green: 0.68, blue: 0.70)
        case .snow: return Color(red: 0.55, green: 0.78, blue: 0.90)
        case .energy: return Color(red: 0.35, green: 0.72, blue: 0.80)
        case .generic: return Color(red: 0.76, green: 0.78, blue: 0.80)
        }
    }
}

// MARK: - MTG card-back placeholder

enum CardBackPlaceholder {
    /// Draws the rounded MTG card-back placeholder used when no image exists.
    static var view: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.mtgSurfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .overlay(
                Image(systemName: "sparkles")
                    .foregroundStyle(.white.opacity(0.35))
            )
    }
}