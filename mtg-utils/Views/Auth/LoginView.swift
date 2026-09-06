import SwiftUI

// MARK: - Login (first screen)

struct LoginView: View {
    @Environment(AppStore.self) private var appStore

    @State private var email = ""
    @State private var password = ""
    @State private var isSigningUp = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.mtgAmber)

            VStack(spacing: 6) {
                Text("MTG Utils")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.mtgText)
                Text("Mazos, colección y completitud sincronizados con el backend.")
                    .font(.subheadline)
                    .foregroundStyle(.mtgTextSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                TextField("Correo electrónico", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.mtgSurface, in: RoundedRectangle(cornerRadius: 12))

                SecureField("Contraseña (mínimo 6 caracteres)", text: $password)
                    .textContentType(isSigningUp ? .newPassword : .password)
                    .padding(12)
                    .background(Color.mtgSurface, in: RoundedRectangle(cornerRadius: 12))
            }

            if let authError = appStore.authError {
                Text(authError)
                    .font(.footnote)
                    .foregroundStyle(Color.mtgRed)
                    .multilineTextAlignment(.center)
            }

            Button {
                submit()
            } label: {
                if appStore.isAuthenticating {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Label(isSigningUp ? "Crear cuenta" : "Iniciar sesión", systemImage: isSigningUp ? "person.badge.plus" : "person.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.mtgAmber)
            .disabled(appStore.isAuthenticating || email.isEmpty || password.isEmpty)

            Button(isSigningUp ? "¿Ya tienes cuenta? Iniciar sesión" : "¿No tienes cuenta? Regístrate") {
                isSigningUp.toggle()
                appStore.authError = nil
            }
            .font(.footnote)
            .foregroundStyle(.mtgTextSecondary)

            HStack(spacing: 12) {
                Rectangle().fill(Color.mtgTextSecondary.opacity(0.3)).frame(height: 1)
                Text("o")
                    .font(.caption)
                    .foregroundStyle(.mtgTextSecondary)
                Rectangle().fill(Color.mtgTextSecondary.opacity(0.3)).frame(height: 1)
            }
            .frame(maxWidth: 240)

            Button {
                Task { await appStore.signInAsGuest() }
            } label: {
                Text("Entrar como invitado (demo)")
                    .font(.headline)
            }
            .disabled(appStore.isAuthenticating)

            Spacer()
        }
        .padding(24)
    }

    private func submit() {
        Task {
            if isSigningUp {
                await appStore.signUp(email: email, password: password)
            } else {
                await appStore.signIn(email: email, password: password)
            }
        }
    }
}

#Preview("Login") {
    LoginView()
        .environment(AppStore())
        .preferredColorScheme(.dark)
}