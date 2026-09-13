import SwiftUI

// MARK: - Account view

struct AccountView: View {
    @Environment(AppStore.self) private var appStore
    @State private var showingSignOut = false

    var body: some View {
        Group {
            if appStore.session.active, let user = appStore.session.user {
                profile(user)
            } else {
                signedOut
            }
        }
        .navigationTitle("Cuenta")
    }

    @MainActor
    private func profile(_ user: AuthUser) -> some View {
        @Bindable var settings = appStore.settings

        return Form {
            Section {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.mtgAmber.opacity(0.25))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Text(String((user.displayName ?? "J").prefix(1)))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.mtgAmber)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName ?? "Jugador")
                            .font(.headline)
                            .foregroundStyle(.mtgText)
                        Text(sessionLabel)
                            .font(.caption)
                            .foregroundStyle(.mtgTextSecondary)
                    }
                }
            }

            Section("Datos") {
                LabeledContent("Origen", value: "Backend (localhost:8000)")
                LabeledContent("Sesión", value: sessionLabel)
                if let email = user.email {
                    LabeledContent("Correo", value: email)
                }
                LabeledContent("ID de usuario", value: user.id)
                Text("Mazos, colección y completitud se sincronizan con el backend a través de tu sesión autenticada.")
                    .font(.footnote)
                    .foregroundStyle(.mtgTextSecondary)
            }

            Section("Ajustes de la aplicación") {
                Picker("Tema", selection: $settings.theme) {
                    ForEach(AppSettings.Theme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.menu)

                Picker("Proveedor de precios", selection: $settings.priceProvider) {
                    ForEach(PriceProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)

                Text(settings.priceProvider.description)
                    .font(.footnote)
                    .foregroundStyle(.mtgTextSecondary)
            }

            Section {
                Button("Cerrar sesión", role: .destructive) {
                    showingSignOut = true
                }
            }
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $showingSignOut, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                appStore.signOut()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Volverás a la pantalla de inicio de sesión.")
        }
    }

    @MainActor
    private var signedOut: some View {
        ContentUnavailableView {
            Label("No has iniciado sesión", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text("Inicia sesión desde la pantalla de bienvenida para ver tus mazos y tu colección.")
        }
    }

    private var sessionLabel: String {
        switch appStore.session.mode {
        case .demo: return "Invitado / demo"
        case .supabase: return "Cuenta autenticada"
        }
    }
}

#Preview("Cuenta") {
    NavigationStack {
        AccountView()
            .environment(AppStore.demo)
    }
    .preferredColorScheme(.dark)
}
