import SwiftUI
import UIKit

struct MainTabView: View {
    let sessionStore: SessionStore
    let inventoryStore: InventoryStore
    let container: DependencyContainer
    @State private var selectedTab = 3  // Start on Dashboard
    @State private var showQuickAccountSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            InsightsView(
                store: inventoryStore,
                selectedTab: $selectedTab,
                isAuthenticated: sessionStore.isAuthenticated,
                isGoogleAccount: sessionStore.authProvider == .google,
                profileImageURL: sessionStore.userAvatarURL,
                onOpenAccount: { showQuickAccountSheet = true }
            )
            .tag(3)
            .tabItem {
                Label("Übersicht", systemImage: "square.grid.2x2.fill")
            }

            InventoryView(
                store: inventoryStore,
                isAuthenticated: sessionStore.isAuthenticated,
                isGoogleAccount: sessionStore.authProvider == .google,
                profileImageURL: sessionStore.userAvatarURL,
                onOpenAccount: { showQuickAccountSheet = true }
            )
            .tag(0)
            .tabItem {
                Label("Inventar", systemImage: "refrigerator.fill")
            }

            ScanTabView(
                receiptRepository: container.receiptRepository,
                normalizationService: container.normalizationService,
                expiryService: container.expiryEstimationService,
                store: inventoryStore,
                useMockAPI: container.useMockAPI,
                notificationManager: container.notificationManager,
                ocrService: container.ocrService,
                isAuthenticated: sessionStore.isAuthenticated,
                isGoogleAccount: sessionStore.authProvider == .google,
                profileImageURL: sessionStore.userAvatarURL,
                onOpenAccount: { showQuickAccountSheet = true }
            )
            .tag(1)
            .tabItem {
                Label("Kamera", systemImage: "camera.fill")
            }

            ShoppingListView(
                store: inventoryStore,
                lowStockService: container.lowStockService,
                isAuthenticated: sessionStore.isAuthenticated,
                isGoogleAccount: sessionStore.authProvider == .google,
                profileImageURL: sessionStore.userAvatarURL,
                onOpenAccount: { showQuickAccountSheet = true }
            )
            .tag(2)
            .tabItem {
                Label("Einkaufsliste", systemImage: "cart.fill")
            }

            SettingsView(
                sessionStore: sessionStore,
                notificationManager: container.notificationManager
            )
            .tag(4)
            .tabItem {
                Label("Einstellungen", systemImage: "gearshape.fill")
            }
        }
        .preferredColorScheme(.light)
        .tint(AppColors.primary)
        .onAppear {
            configureTabBarAppearance()
        }
        .task {
            await inventoryStore.loadInventory()
        }
        .sheet(isPresented: $showQuickAccountSheet) {
            QuickAccountSheet(
                sessionStore: sessionStore,
                onOpenAccount: {
                    showQuickAccountSheet = false
                    selectedTab = 4
                }
            )
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.2)

        let normalColor = UIColor.darkGray.withAlphaComponent(0.85)
        let selectedColor = UIColor(red: 19 / 255, green: 236 / 255, blue: 19 / 255, alpha: 1)

        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance]
            .forEach { itemAppearance in
                itemAppearance.normal.iconColor = normalColor
                itemAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
                itemAppearance.selected.iconColor = selectedColor
                itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
            }

        let proxy = UITabBar.appearance()
        proxy.standardAppearance = appearance
        proxy.scrollEdgeAppearance = appearance
        proxy.isTranslucent = true
        proxy.isHidden = false
    }
}

// MARK: - Profile Toolbar Button

struct ProfileToolbarButton: View {
    let isAuthenticated: Bool
    let isGoogleAccount: Bool
    let profileImageURL: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                avatarContent

                if isAuthenticated {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 8, height: 8)
                        .overlay {
                            Circle()
                                .stroke(AppColors.background, lineWidth: 1)
                        }
                }
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Konto")
        .accessibilityHint("Konto und Einstellungen öffnen")
    }

    @ViewBuilder
    private var avatarContent: some View {
        if isGoogleAccount,
           let profileImageURL,
           let url = URL(string: profileImageURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(AppColors.primary, lineWidth: 2)
            }
        } else {
            Image(systemName: "person.crop.circle")
                .font(.title3.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}

// MARK: - Quick Account Sheet

private struct QuickAccountSheet: View {
    let sessionStore: SessionStore
    let onOpenAccount: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: AppSpacing.l) {
                    ProfileToolbarButton(
                        isAuthenticated: sessionStore.isAuthenticated,
                        isGoogleAccount: sessionStore.authProvider == .google,
                        profileImageURL: sessionStore.userAvatarURL,
                        action: {}
                    )
                    .frame(width: 56, height: 56)

                    VStack(spacing: AppSpacing.xs) {
                        Text(sessionStore.userName ?? "Benutzer")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary)

                        if let email = sessionStore.userEmail, !email.isEmpty {
                            Text(email)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        Text(providerLabel)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    VStack(spacing: AppSpacing.s) {
                        Button {
                            dismiss()
                            onOpenAccount()
                        } label: {
                            Label("Konto öffnen", systemImage: "person.crop.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())

                        Button(role: .destructive) {
                            dismiss()
                            sessionStore.signOut()
                        } label: {
                            Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.xl)
            }
            .navigationTitle("Konto")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(AppSpacing.cardRadiusLarge)
    }

    private var providerLabel: String {
        switch sessionStore.authProvider {
        case .google:
            return "Angemeldet mit Google"
        case .apple:
            return "Angemeldet mit Apple"
        case nil:
            return "Angemeldet"
        }
    }
}
