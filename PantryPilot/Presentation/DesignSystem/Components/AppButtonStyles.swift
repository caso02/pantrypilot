import SwiftUI

struct AppPrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.m)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(AppColors.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.m)
            .background(.regularMaterial)
            .foregroundStyle(AppColors.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous)
                    .strokeBorder(AppColors.primary.opacity(0.2), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct AppDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.m)
            .background(AppColors.danger.opacity(0.1))
            .foregroundStyle(AppColors.danger)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
