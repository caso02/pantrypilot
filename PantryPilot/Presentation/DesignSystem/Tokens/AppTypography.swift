import SwiftUI

enum AppTypography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let headline1 = Font.system(.title2, design: .rounded, weight: .bold)
    static let headline2 = Font.system(.title3, design: .rounded, weight: .semibold)
    static let title = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let bodyMedium = Font.system(.body, design: .default, weight: .medium)
    static let callout = Font.system(.callout, design: .default, weight: .regular)
    static let caption = Font.system(.caption, design: .default, weight: .regular)
    static let captionMedium = Font.system(.caption, design: .default, weight: .medium)
    static let caption2 = Font.system(.caption2, design: .default, weight: .medium)
    static let metric = Font.system(.title, design: .rounded, weight: .bold)
}
