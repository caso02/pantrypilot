import Foundation
import os

enum AppLogger {
    static let general = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pantrypilot", category: "general")
    static let network = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pantrypilot", category: "network")
    static let persistence = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pantrypilot", category: "persistence")
    static let camera = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pantrypilot", category: "camera")
    static let notifications = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pantrypilot", category: "notifications")
}
