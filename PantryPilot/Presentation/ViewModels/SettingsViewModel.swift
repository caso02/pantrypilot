import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    enum BackendPreset: String, CaseIterable, Identifiable {
        case local
        case render
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .local: return "Lokal (192.168.1.61)"
            case .render: return "Cloud (Render)"
            case .custom: return "Eigene URL"
            }
        }
    }

    static let localBackendURL = "http://192.168.1.61:3000"
    static let renderBackendURL = "https://pantrypilot-xltu.onrender.com"

    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    var privacyMode: Bool {
        didSet { UserDefaults.standard.set(privacyMode, forKey: "privacyMode") }
    }
    var useMockAPI: Bool {
        didSet { UserDefaults.standard.set(useMockAPI, forKey: "useMockAPI") }
    }
    var backendURL: String {
        didSet { UserDefaults.standard.set(backendURL, forKey: "backendURL") }
    }

    private let sessionStore: SessionStore
    private let notificationManager: NotificationManager

    init(sessionStore: SessionStore, notificationManager: NotificationManager) {
        self.sessionStore = sessionStore
        self.notificationManager = notificationManager
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        self.privacyMode = UserDefaults.standard.bool(forKey: "privacyMode")
        self.useMockAPI = UserDefaults.standard.object(forKey: "useMockAPI") != nil
            ? UserDefaults.standard.bool(forKey: "useMockAPI")
            : (ProcessInfo.processInfo.environment["USE_MOCK_API"] == "1")
        self.backendURL = UserDefaults.standard.string(forKey: "backendURL")
            ?? DependencyContainer.defaultBackendURL.absoluteString
    }

    var isAuthenticated: Bool { sessionStore.isAuthenticated }
    var userName: String? { sessionStore.userName }
    var userEmail: String? { sessionStore.userEmail }

    func requestNotificationPermission() async {
        await notificationManager.requestPermission()
        notificationsEnabled = notificationManager.isAuthorized
    }

    func signOut() {
        sessionStore.signOut()
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var selectedBackendPreset: BackendPreset {
        let normalized = backendURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == Self.localBackendURL.lowercased() {
            return .local
        }
        if normalized == Self.renderBackendURL.lowercased() {
            return .render
        }
        return .custom
    }

    func setBackendPreset(_ preset: BackendPreset) {
        switch preset {
        case .local:
            backendURL = Self.localBackendURL
        case .render:
            backendURL = Self.renderBackendURL
        case .custom:
            break
        }
    }
}
