import SwiftUI
import AuthenticationServices

struct SignInView: View {
    let sessionStore: SessionStore
    @State private var errorMessage: String?
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
        VStack(spacing: AppSpacing.l) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleSignInResult(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
            .padding(.horizontal, AppSpacing.xxl)

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

    // MARK: - Logic

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unerwarteter Anmeldefehler."
                return
            }

            sessionStore.signInWithApple(
                userID: credential.user,
                identityToken: credential.identityToken,
                fullName: credential.fullName,
                email: credential.email
            )

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = "Anmeldung fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
