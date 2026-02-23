import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "cart.fill",
            iconColor: .blue,
            title: "Willkommen bei PantryPilot",
            subtitle: "Dein smarter Küchenassistent. Behalte den Überblick über deine Vorräte und vermeide Food-Waste."
        ),
        OnboardingPage(
            icon: "doc.text.viewfinder",
            iconColor: .orange,
            title: "Kassenzettel scannen",
            subtitle: "Fotografiere deinen Kassenzettel — die App erkennt automatisch alle Produkte und fügt sie deinem Inventar hinzu."
        ),
        OnboardingPage(
            icon: "clock.badge.exclamationmark",
            iconColor: .red,
            title: "Nie mehr vergessen",
            subtitle: "PantryPilot erinnert dich, wenn Produkte bald ablaufen, und schlägt vor, was du zuerst verwenden solltest."
        ),
        OnboardingPage(
            icon: "list.clipboard.fill",
            iconColor: .green,
            title: "Smarte Einkaufsliste",
            subtitle: "Leere Vorräte werden automatisch vorgeschlagen. Deine Einkaufsliste wird dauerhaft gespeichert."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            bottomSection
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    // MARK: - Page

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(page.iconColor)
            }
            .padding(.bottom, AppSpacing.l)

            Text(page.title)
                .font(AppTypography.headline1)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Text(page.subtitle)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xxl)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom

    private var bottomSection: some View {
        VStack(spacing: AppSpacing.l) {
            HStack(spacing: AppSpacing.s) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? AppColors.primary : AppColors.textTertiary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentPage ? 1.2 : 1)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            if currentPage == pages.count - 1 {
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text("Los geht's")
                        .font(AppTypography.bodyMedium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .padding(.horizontal, AppSpacing.xxl)
            } else {
                HStack {
                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Überspringen")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            currentPage += 1
                        }
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Text("Weiter")
                                .font(AppTypography.bodyMedium)
                            Image(systemName: "arrow.right")
                                .font(.body.weight(.medium))
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
            }
        }
        .padding(.bottom, AppSpacing.xxl)
    }
}

// MARK: - Model

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}
