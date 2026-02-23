import SwiftUI

struct AppPillBadge: View {
    let text: String
    var color: Color = AppColors.primary
    var style: PillStyle = .filled

    enum PillStyle { case filled, subtle }

    var body: some View {
        Text(text)
            .font(AppTypography.caption2)
            .padding(.horizontal, AppSpacing.s)
            .padding(.vertical, AppSpacing.xs)
            .background(pillBackground)
            .foregroundStyle(pillForeground)
            .clipShape(Capsule())
    }

    private var pillBackground: Color {
        switch style {
        case .filled: return color.opacity(0.15)
        case .subtle: return color.opacity(0.08)
        }
    }

    private var pillForeground: Color { color }
}
