import SwiftUI

enum AppColors {
    static let primary = Color(red: 19/255, green: 236/255, blue: 19/255)
    static let primaryForeground = Color.black
    static let background = Color.white
    static let surface = Color.white
    static let surfaceElevated = Color(.tertiarySystemGroupedBackground)
    static let textPrimary = Color.black
    static let textSecondary = Color.black.opacity(0.7)
    static let textTertiary = Color.black.opacity(0.5)
    static let separator = Color(.separator)

    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    static let info = Color.blue

    static let cardShadow = Color.black.opacity(0.06)
    static let cardStroke = Color(red: 19/255, green: 236/255, blue: 19/255).opacity(0.1)

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
