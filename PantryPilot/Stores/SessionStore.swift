import Foundation
import SwiftUI
import AuthenticationServices

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
}
