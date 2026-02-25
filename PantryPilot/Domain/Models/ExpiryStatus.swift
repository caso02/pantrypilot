import Foundation
import SwiftUI

enum ExpiryStatus: Equatable {
    case fresh(daysLeft: Int)
    case soon(daysLeft: Int)
    case expired(daysPast: Int)
    case unknown

    init(expiryDate: Date?) {
        guard let expiry = expiryDate else {
            self = .unknown
            return
        }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: expiry)).day ?? 0
        if days < 0 {
            self = .expired(daysPast: abs(days))
        } else if days <= 3 {
            self = .soon(daysLeft: days)
        } else {
            self = .fresh(daysLeft: days)
        }
    }

    var label: String {
        switch self {
        case .fresh(let days):
            return "Noch \(days) Tage"
        case .soon(let days):
            if days == 0 { return "Heute" }
            if days == 1 { return "Morgen" }
            return "Noch \(days) Tage"
        case .expired(let days):
            if days == 0 { return "Heute abgelaufen" }
            if days == 1 { return "Seit 1 Tag abgelaufen" }
            return "Seit \(days) Tagen abgelaufen"
        case .unknown:
            return ""
        }
    }

    /// Compact label for pills in list rows
    var shortLabel: String {
        switch self {
        case .fresh(let days):
            return "Noch \(days) Tage"
        case .soon(let days):
            if days == 0 { return "Heute" }
            if days == 1 { return "Morgen" }
            return "Noch \(days) Tage"
        case .expired:
            return "Abgelaufen"
        case .unknown:
            return ""
        }
    }

    var color: Color {
        switch self {
        case .fresh(let days):
            if days <= 7 { return .yellow }
            return .green
        case .soon(let days):
            // Visual urgency scale: <=1 day red, <=3 days orange.
            if days <= 1 { return .red }
            return .orange
        case .expired:
            return .red
        case .unknown: return .secondary
        }
    }

    var isExpired: Bool {
        if case .expired = self { return true }
        return false
    }

    var isSoon: Bool {
        if case .soon = self { return true }
        return false
    }

    var isUrgent: Bool { isExpired || isSoon }
}
