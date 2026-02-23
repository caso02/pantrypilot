import SwiftUI

struct AppIconBadge: View {
    let icon: String
    var color: Color = AppColors.primary
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.iconBadgeRadius, style: .continuous))
    }
}
