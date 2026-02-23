import SwiftUI

enum AppColors {
    static let primary = Color.accentColor
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let surfaceElevated = Color(.tertiarySystemGroupedBackground)
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
    static let separator = Color(.separator)

    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    static let info = Color.blue

    static let cardShadow = Color.black.opacity(0.06)
    static let cardStroke = Color(.separator).opacity(0.3)

    static func categoryColor(for category: FoodCategory?) -> Color {
        switch category {
        case .dairy: return .blue
        case .meat: return .red
        case .produce: return .green
        case .bakery: return .brown
        case .frozen: return .cyan
        case .canned: return .gray
        case .beverages: return .teal
        case .snacks: return .orange
        case .condiments: return .yellow
        case .grains: return .indigo
        case .other, .none: return .secondary
        }
    }

    static func categoryIcon(for category: FoodCategory?) -> String {
        switch category {
        case .dairy: return "cup.and.saucer.fill"
        case .meat: return "fork.knife"
        case .produce: return "leaf.fill"
        case .bakery: return "birthday.cake.fill"
        case .frozen: return "snowflake"
        case .canned: return "cylinder.fill"
        case .beverages: return "drop.fill"
        case .snacks: return "bag.fill"
        case .condiments: return "flame.fill"
        case .grains: return "oval.portrait.fill"
        case .other, .none: return "basket.fill"
        }
    }
}
