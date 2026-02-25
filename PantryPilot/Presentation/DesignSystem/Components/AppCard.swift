import SwiftUI

enum CardElevation {
    case none
    case low
    case medium

    var shadowRadius: CGFloat {
        switch self {
        case .none: return 0
        case .low: return 2
        case .medium: return 5
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .none: return 0
        case .low: return 0.04
        case .medium: return 0.06
        }
    }
}

struct AppCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.l
    var elevation: CardElevation = .low
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .fill(AppColors.surface)
                    .shadow(
                        color: .black.opacity(elevation.shadowOpacity),
                        radius: elevation.shadowRadius,
                        y: elevation.shadowY
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 0.5)
            }
    }
}

struct AppCardPlain<Content: View>: View {
    var padding: CGFloat = AppSpacing.l
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .fill(AppColors.surface)
            }
    }
}
