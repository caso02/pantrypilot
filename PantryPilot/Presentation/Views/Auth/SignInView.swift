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

            LinearGradient(
                colors: [
                    AppColors.primary.opacity(0.06),
                    Color.clear,
                    AppColors.primary.opacity(0.03),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                heroSection

                Spacer()

                signInSection
                    .padding(.bottom, AppSpacing.xxl)
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: AppSpacing.xl) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.08))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(AppColors.primary.opacity(0.12))
                    .frame(width: 110, height: 110)

                Image(systemName: "cart.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(AppColors.primary)
            }

            VStack(spacing: AppSpacing.m) {
                Text("PantryPilot")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Dein smarter Küchenassistent")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
            }

            featureList
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            featureRow(icon: "doc.text.viewfinder", text: "Kassenzettel scannen & erkennen")
            featureRow(icon: "clock.badge.exclamationmark", text: "Ablauf-Erinnerungen erhalten")
            featureRow(icon: "icloud.fill", text: "Daten sicher in der Cloud speichern")
        }
        .padding(.top, AppSpacing.l)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.m) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(AppColors.primary)
                .frame(width: 28)

            Text(text)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Sign In

    private var signInSection: some View {
        VStack(spacing: AppSpacing.m) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleSignInResult(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
            .padding(.horizontal, AppSpacing.xxl)

            googleSignInButton

            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }

            Text("Mit der Anmeldung akzeptierst du unsere\nNutzungsbedingungen und Datenschutzrichtlinie.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xxl)
        }
    }

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
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isGoogleLoading)
        .padding(.horizontal, AppSpacing.xxl)
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
