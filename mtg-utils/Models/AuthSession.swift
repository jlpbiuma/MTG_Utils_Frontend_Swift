import Foundation

// MARK: - Auth session (demo)

enum AuthMode: String, CaseIterable, Identifiable {
    case demo
    case supabase

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .demo: return "Modo demo"
        case .supabase: return "Con cuenta"
        }
    }
}

struct AuthUser: Hashable {
    var id: String
    var email: String?
    var displayName: String?
}

struct AuthSession: Hashable {
    var active: Bool
    var user: AuthUser?
    var mode: AuthMode
}

/// Default demo session used while Supabase auth is not configured.
enum DemoSession {
    static var guest: AuthSession {
        AuthSession(
            active: true,
            user: AuthUser(
                id: MockDataStore.demoUserId,
                email: nil,
                displayName: "Jugador Demo"
            ),
            mode: .demo
        )
    }
}