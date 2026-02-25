import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct SignInView: View {
    let sessionStore: SessionStore
    @State private var errorMessage: String?
    @State private var isGoogleLoading = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header bar
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.primary.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "refrigerator.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(AppColors.primary)
                        }
                    Spacer()
                    Text("PantryPilot")
                        .font(.headline.bold())
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(16)
                Rectangle()
                    .fill(AppColors.primary.opacity(0.08))
                    .frame(height: 1)

                ScrollView {
                    VStack(spacing: 24) {
                        // Hero
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.primary.opacity(0.07))
                            .frame(height: 180)
                            .overlay {
                                VStack(spacing: 12) {
                                    Image(systemName: "refrigerator.fill")
                                        .font(.system(size: 52, weight: .light))
                                        .foregroundStyle(AppColors.primary.opacity(0.5))
                                    Text("Smart Kitchen")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppColors.primary.opacity(0.6))
                                        .textCase(.uppercase)
                                        .tracking(1)
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.primary.opacity(0.15), lineWidth: 1)
                            }

                        // Title
                        VStack(spacing: 8) {
                            Text("Willkommen bei PantryPilot")
                                .font(.system(size: 26, weight: .heavy))
                                .multilineTextAlignment(.center)
                            Text("Verwalte deine Küche mit Leichtigkeit")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Social Buttons
                        VStack(spacing: 12) {
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                handleSignInResult(result)
                            }
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            googleSignInButton
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(AppColors.danger)
                                .multilineTextAlignment(.center)
                        }

                        // Footer
                        Text("Datenschutz · Nutzungsbedingungen")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(24)
                }
            }
        }
    }

    // MARK: - Sign In (kept for compatibility)

    private var googleSignInButton: some View {
        Button {
            Task { await handleGoogleSignIn() }
        } label: {
            HStack(spacing: 10) {
                if isGoogleLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .frame(width: 20, height: 20)
                } else {
                    // Google "G" Icon aus SF Symbols Buchstaben zusammengebaut
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                        Text("G")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                    }
                }
                Text("Mit Google anmelden")
                    .font(.system(size: 17, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
            .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isGoogleLoading)
    }

    // MARK: - Logic

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unerwarteter Anmeldefehler."
                return
            }

            Task {
                do {
                    try await sessionStore.signInWithApple(
                        userID: credential.user,
                        identityToken: credential.identityToken,
                        fullName: credential.fullName,
                        email: credential.email
                    )
                } catch {
                    errorMessage = "Apple Anmeldung fehlgeschlagen: \(error.localizedDescription)"
                }
            }

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = "Anmeldung fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func handleGoogleSignIn() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Anmeldung nicht möglich."
            return
        }
        isGoogleLoading = true
        errorMessage = nil
        defer { isGoogleLoading = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google ID-Token fehlt."
                return
            }
            let email = result.user.profile?.email
            let displayName = result.user.profile?.name
            let avatarURL = result.user.profile?.imageURL(withDimension: 96)?.absoluteString
            try await sessionStore.signInWithGoogle(
                idToken: idToken,
                email: email,
                displayName: displayName,
                avatarURL: avatarURL
            )
        } catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                return
            }
            errorMessage = "Google Anmeldung fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
