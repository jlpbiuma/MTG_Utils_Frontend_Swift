import Foundation
import Observation

// MARK: - App-level state

/// Root observable state shared across the whole app: auth session + data store.
/// All decks/collection data is served by the MTG Utils backend at localhost:8000.
@Observable
@MainActor
final class AppStore {
    let client: BackendClient
    let catalog: ScryfallClient
    let store: BackendDataStore

    private(set) var session: AuthSession
    private(set) var isAuthenticating = false
    var authError: String?

    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    var userId: String { session.user?.id ?? BackendDataStore.demoUserId }

    private static let savedSessionKey = "mtg.savedSession"

    init(client: BackendClient = .shared, catalog: ScryfallClient = .shared) {
        self.client = client
        self.catalog = catalog
        self.session = AuthSession(active: false, user: nil, mode: .demo)
        self.store = BackendDataStore(client: client)
        restoreSavedSession()
    }

    /// Signed-in instance used by SwiftUI previews.
    static var demo: AppStore {
        let app = AppStore()
        app.session = DemoSession.guest
        app.store.userId = app.session.user?.id ?? BackendDataStore.demoUserId
        app.accessToken = "demo-access-token"
        app.store.accessToken = app.accessToken
        return app
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async {
        isAuthenticating = true
        authError = nil
        defer { isAuthenticating = false }

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.contains("@") else {
            authError = "Introduce un correo electrónico válido."
            return
        }
        guard password.count >= 6 else {
            authError = "La contraseña debe tener al menos 6 caracteres."
            return
        }

        let response: BackendAuthResponse
        do {
            response = try await client.authLogin(email: trimmed, password: password)
        } catch {
            authError = "No se pudo conectar con el backend en \(client.baseURL.absoluteString). ¿Está el servicio corriendo en el puerto 8000?"
            return
        }
        guard handleResponse(response, mode: .supabase, email: trimmed) else { return }
    }

    func signUp(email: String, password: String) async {
        isAuthenticating = true
        authError = nil
        defer { isAuthenticating = false }

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.contains("@") else {
            authError = "Introduce un correo electrónico válido."
            return
        }
        guard password.count >= 6 else {
            authError = "La contraseña debe tener al menos 6 caracteres."
            return
        }

        let response: BackendAuthResponse
        do {
            response = try await client.authSignup(email: trimmed, password: password)
        } catch {
            authError = "No se pudo conectar con el backend en \(client.baseURL.absoluteString). ¿Está el servicio corriendo en el puerto 8000?"
            return
        }

        if let errorMessage = response.error {
            authError = errorMessage
            return
        }
        if response.needsConfirmation {
            authError = "Cuenta creada. Revisa tu correo para confirmarla antes de iniciar sesión."
            return
        }
        guard apply(response: response, mode: .supabase) else { return }
    }

    func signInAsGuest() async {
        isAuthenticating = true
        authError = nil
        defer { isAuthenticating = false }

        let response: BackendAuthResponse
        do {
            response = try await client.authLogin(email: "demo@magic.io", password: "demo1234")
        } catch {
            authError = "No se pudo conectar con el backend en \(client.baseURL.absoluteString). ¿Está el servicio corriendo en el puerto 8000?"
            return
        }
        guard handleResponse(response, mode: .demo, email: "demo@magic.io") else { return }
    }

    func signOut() {
        let token = accessToken
        session = AuthSession(active: false, user: nil, mode: .demo)
        accessToken = nil
        refreshToken = nil
        store.accessToken = nil
        UserDefaults.standard.removeObject(forKey: Self.savedSessionKey)
        Task { try? await client.logout(accessToken: token) }
    }

    func refreshSessionIfNeeded() async {
        guard session.active, let refreshToken = self.refreshToken else { return }
        // Best-effort refresh/validation against the backend.
        if let user = (try? await client.authMe(accessToken: accessToken ?? "")) {
            _ = user
            return
        }
        let response = (try? await client.authRefresh(refreshToken: refreshToken))
        guard let response, response.error == nil else { return }
        _ = apply(response: response, mode: session.mode)
    }

    // MARK: - Helpers

    /// `true` if the response established a session; `false` if an error was surfaced.
    @discardableResult
    private func handleResponse(_ response: BackendAuthResponse, mode: AuthMode, email: String) -> Bool {
        if let errorMessage = response.error {
            authError = errorMessage
            return false
        }
        if response.needsConfirmation {
            authError = "Revisa tu correo (\(email)) y confirma la cuenta antes de iniciar sesión."
            return false
        }
        return apply(response: response, mode: mode)
    }

    @discardableResult
    private func apply(response: BackendAuthResponse, mode: AuthMode) -> Bool {
        guard let user = response.user, let token = response.accessToken, !token.isEmpty else {
            authError = "El backend no devolvió una sesión válida."
            return false
        }
        session = AuthSession(
            active: true,
            user: AuthUser(id: user.id, email: user.email, displayName: user.name),
            mode: mode
        )
        accessToken = token
        refreshToken = response.refreshToken
        store.userId = user.id
        store.accessToken = token
        persistSession()
        return true
    }

    private func persistSession() {
        guard let user = session.user, let token = accessToken else { return }
        let saved = SavedSession(
            userId: user.id,
            email: user.email,
            displayName: user.displayName,
            accessToken: token,
            refreshToken: refreshToken,
            mode: session.mode.rawValue
        )
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.savedSessionKey)
        }
    }

    private func restoreSavedSession() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.savedSessionKey),
            let saved = try? JSONDecoder().decode(SavedSession.self, from: data),
            !saved.userId.isEmpty
        else { return }
        session = AuthSession(
            active: true,
            user: AuthUser(id: saved.userId, email: saved.email, displayName: saved.displayName),
            mode: AuthMode(rawValue: saved.mode) ?? .demo
        )
        accessToken = saved.accessToken
        refreshToken = saved.refreshToken
        store.userId = saved.userId
        store.accessToken = saved.accessToken
    }
}

private struct SavedSession: Codable {
    var userId: String
    var email: String?
    var displayName: String?
    var accessToken: String?
    var refreshToken: String?
    var mode: String
}

// MARK: - Tab definition

enum AppTab: Hashable {
    case decks
    case collection
    case account
}