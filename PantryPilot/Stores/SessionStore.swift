import Foundation
import SwiftUI
import AuthenticationServices
import GoogleSignIn

@Observable
@MainActor
final class SessionStore {
    private(set) var isAuthenticated = false
    private(set) var token: String?
    private(set) var userName: String?
    private(set) var userEmail: String?

    private let tokenKey = "authToken"
    private let userIdKey = "appleUserID"
    private let userNameKey = "userName"
    private let userEmailKey = "userEmail"

    init() {
        if let stored = KeychainWrapper.loadString(forKey: tokenKey) {
            self.token = stored
            self.isAuthenticated = true
            self.userName = UserDefaults.standard.string(forKey: userNameKey)
            self.userEmail = UserDefaults.standard.string(forKey: userEmailKey)
        }
    }

    func signInWithApple(
        userID: String,
        identityToken: Data?,
        fullName: PersonNameComponents?,
        email: String?
    ) {
        let tokenString = identityToken.flatMap { String(data: $0, encoding: .utf8) } ?? userID

        do {
            try KeychainWrapper.saveString(tokenString, forKey: tokenKey)
            try KeychainWrapper.saveString(userID, forKey: userIdKey)
        } catch {
            AppLogger.general.error("Keychain save failed: \(error.localizedDescription)")
        }

        self.token = tokenString
        self.isAuthenticated = true

        if let name = fullName {
            let displayName = [name.givenName, name.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !displayName.isEmpty {
                self.userName = displayName
                UserDefaults.standard.set(displayName, forKey: userNameKey)
            }
        }

        if let email, !email.isEmpty {
            self.userEmail = email
            UserDefaults.standard.set(email, forKey: userEmailKey)
        }
    }

    func signInWithGoogle(idToken: String, email: String?, displayName: String?) async throws {
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
            throw GoogleSignInError.backendErrorDetailed(status: statusCode, body: body)
        }

        struct AuthResponse: Decodable {
            let token: String
            struct UserInfo: Decodable {
                let displayName: String?
                let email: String?
            }
            let user: UserInfo
        }
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)

        signIn(token: authResponse.token)

        let resolvedName = authResponse.user.displayName ?? displayName ?? ""
        if !resolvedName.isEmpty {
            self.userName = resolvedName
            UserDefaults.standard.set(resolvedName, forKey: userNameKey)
        }
        let resolvedEmail = authResponse.user.email ?? email ?? ""
        if !resolvedEmail.isEmpty {
            self.userEmail = resolvedEmail
            UserDefaults.standard.set(resolvedEmail, forKey: userEmailKey)
        }
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
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
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
}

enum GoogleSignInError: LocalizedError {
    case backendError
    case backendErrorDetailed(status: Int, body: String)
    var errorDescription: String? {
        switch self {
        case .backendError:
            return "Anmeldung am Server fehlgeschlagen. Bitte erneut versuchen."
        case .backendErrorDetailed(let status, let body):
            return "Server-Fehler \(status): \(body)"
        }
    }
}
