import SwiftUI

struct AppEmptyState: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var ctaLabel: String? = nil
    var ctaAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.l) {
            Image(systemName: icon)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.bottom, AppSpacing.xs)

            Text(title)
                .font(AppTypography.headline2)
                .foregroundStyle(AppColors.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }

            if let ctaLabel, let ctaAction {
                Button(action: ctaAction) {
                    Label(ctaLabel, systemImage: "plus")
                        .font(AppTypography.bodyMedium)
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .padding(.top, AppSpacing.s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
    }
}
