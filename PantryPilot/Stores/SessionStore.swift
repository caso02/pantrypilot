import Foundation
import SwiftUI
import AuthenticationServices
import GoogleSignIn

enum AuthProvider: String {
    case apple
    case google
}

@Observable
@MainActor
final class SessionStore {
    private(set) var isAuthenticated = false
    private(set) var token: String?
    private(set) var userName: String?
    private(set) var userEmail: String?
    private(set) var userAvatarURL: String?
    private(set) var authProvider: AuthProvider?
    private(set) var shouldShowOnboardingAfterSignIn: Bool

    private let tokenKey = "authToken"
    private let userIdKey = "appleUserID"
    private let userNameKey = "userName"
    private let userEmailKey = "userEmail"
    private let userAvatarURLKey = "userAvatarURL"
    private let authProviderKey = "authProvider"
    private let onboardingAfterSignInKey = "shouldShowOnboardingAfterSignIn"

    init() {
        self.shouldShowOnboardingAfterSignIn = UserDefaults.standard.bool(forKey: onboardingAfterSignInKey)
        if let stored = KeychainWrapper.loadString(forKey: tokenKey) {
            self.token = stored
            self.isAuthenticated = true
            self.userName = UserDefaults.standard.string(forKey: userNameKey)
            self.userEmail = UserDefaults.standard.string(forKey: userEmailKey)
            self.userAvatarURL = UserDefaults.standard.string(forKey: userAvatarURLKey)
            self.authProvider = UserDefaults.standard.string(forKey: authProviderKey).flatMap(AuthProvider.init(rawValue:))
        }
    }

    func signInWithApple(
        userID: String,
        identityToken: Data?,
        fullName: PersonNameComponents?,
        email: String?
    ) async throws {
        guard let identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8),
              !identityTokenString.isEmpty else {
            throw AuthError.appleIdentityTokenMissing
        }

        let backendURLString = UserDefaults.standard.string(forKey: "backendURL")
        let baseURL = URL(string: backendURLString ?? "") ?? backendDefaultURL
        let url = baseURL.appendingPathComponent("/v1/auth/apple")

        struct AppleAuthBody: Encodable {
            let identityToken: String
            let userId: String
            let email: String?
            let displayName: String?
        }

        let displayName = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let normalizedDisplayName = displayName.isEmpty ? nil : displayName

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AppleAuthBody(
            identityToken: identityTokenString,
            userId: userID,
            email: email,
            displayName: normalizedDisplayName
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            AppLogger.general.error("Apple auth backend error \(statusCode): \(body)")
            throw AuthError.backendErrorDetailed(status: statusCode, body: body)
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        applyAuthResponse(
            authResponse,
            provider: .apple,
            fallbackName: normalizedDisplayName,
            fallbackEmail: email,
            fallbackAvatarURL: nil
        )

        do {
            try KeychainWrapper.saveString(userID, forKey: userIdKey)
        } catch {
            AppLogger.general.error("Keychain save failed: \(error.localizedDescription)")
        }
    }

    func signInWithGoogle(idToken: String, email: String?, displayName: String?, avatarURL: String?) async throws {
        let backendURLString = UserDefaults.standard.string(forKey: "backendURL")
        let baseURL = URL(string: backendURLString ?? "") ?? backendDefaultURL
        let url = baseURL.appendingPathComponent("/v1/auth/google")

        struct GoogleAuthBody: Encodable {
            let idToken: String
            let displayName: String?
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GoogleAuthBody(idToken: idToken, displayName: displayName))

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            AppLogger.general.error("Google auth backend error \(statusCode): \(body)")
            throw AuthError.backendErrorDetailed(status: statusCode, body: body)
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        applyAuthResponse(
            authResponse,
            provider: .google,
            fallbackName: displayName,
            fallbackEmail: email,
            fallbackAvatarURL: avatarURL
        )
    }

    func signIn(token: String) {
        do {
            try KeychainWrapper.saveString(token, forKey: tokenKey)
            self.token = token
            self.isAuthenticated = true
        } catch {
            AppLogger.general.error("Keychain save failed: \(error.localizedDescription)")
        }
    }

    func signOut() {
        do {
            try KeychainWrapper.delete(key: tokenKey)
            try KeychainWrapper.delete(key: userIdKey)
        } catch {
            AppLogger.general.error("Keychain delete failed: \(error.localizedDescription)")
        }
        GIDSignIn.sharedInstance.signOut()
        self.token = nil
        self.isAuthenticated = false
        self.userName = nil
        self.userEmail = nil
        self.userAvatarURL = nil
        self.authProvider = nil
        self.shouldShowOnboardingAfterSignIn = false
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userAvatarURLKey)
        UserDefaults.standard.removeObject(forKey: authProviderKey)
        UserDefaults.standard.set(false, forKey: onboardingAfterSignInKey)
    }

    func completeOnboardingAfterSignIn() {
        shouldShowOnboardingAfterSignIn = false
        UserDefaults.standard.set(false, forKey: onboardingAfterSignInKey)
    }

    func checkAppleCredentialState() async {
        guard let userID = KeychainWrapper.loadString(forKey: userIdKey) else { return }
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userID)
            if state == .revoked || state == .notFound {
                signOut()
            }
        } catch {
            AppLogger.general.error("Credential state check failed: \(error.localizedDescription)")
        }
    }

    private var backendDefaultURL: URL {
        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:3000")!
        #else
        return URL(string: "http://192.168.1.61:3000")!
        #endif
    }

    private func applyAuthResponse(
        _ authResponse: AuthResponse,
        provider: AuthProvider,
        fallbackName: String?,
        fallbackEmail: String?,
        fallbackAvatarURL: String?
    ) {
        signIn(token: authResponse.token)
        authProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: authProviderKey)

        shouldShowOnboardingAfterSignIn = authResponse.isNewUser
        UserDefaults.standard.set(authResponse.isNewUser, forKey: onboardingAfterSignInKey)

        let resolvedName = authResponse.user.displayName ?? fallbackName ?? ""
        if !resolvedName.isEmpty {
            self.userName = resolvedName
            UserDefaults.standard.set(resolvedName, forKey: userNameKey)
        }

        let resolvedEmail = authResponse.user.email ?? fallbackEmail ?? ""
        if !resolvedEmail.isEmpty {
            self.userEmail = resolvedEmail
            UserDefaults.standard.set(resolvedEmail, forKey: userEmailKey)
        }

        if provider == .google, let fallbackAvatarURL, !fallbackAvatarURL.isEmpty {
            self.userAvatarURL = fallbackAvatarURL
            UserDefaults.standard.set(fallbackAvatarURL, forKey: userAvatarURLKey)
        } else {
            self.userAvatarURL = nil
            UserDefaults.standard.removeObject(forKey: userAvatarURLKey)
        }
    }
}

private struct AuthResponse: Decodable {
    let token: String
    let isNewUser: Bool

    struct UserInfo: Decodable {
        let displayName: String?
        let email: String?
    }

    let user: UserInfo
}

enum AuthError: LocalizedError {
    case appleIdentityTokenMissing
    case backendErrorDetailed(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .appleIdentityTokenMissing:
            return "Apple Identity-Token fehlt. Bitte Anmeldung erneut starten."
        case .backendErrorDetailed(let status, let body):
            return "Server-Fehler \(status): \(body)"
        }
    }
}
