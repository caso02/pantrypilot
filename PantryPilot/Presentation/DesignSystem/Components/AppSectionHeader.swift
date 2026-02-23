import SwiftUI

struct AppSectionHeader: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = AppColors.textSecondary
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            if let trailing, let action = trailingAction {
                Button(action: action) {
                    Text(trailing)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.xs)
    }
}
