import SwiftUI

struct MainTabView: View {
    let sessionStore: SessionStore
    let inventoryStore: InventoryStore
    let container: DependencyContainer
    @State private var selectedTab = 0
    @State private var showQuickAccountSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            InventoryView(
                store: inventoryStore,
                isAuthenticated: sessionStore.isAuthenticated,
                isGoogleAccount: sessionStore.authProvider == .google,
                profileImageURL: sessionStore.userAvatarURL,
                onOpenAccount: { showQuickAccountSheet = true }
            )
                .tabItem { Label("Inventar", systemImage: "refrigerator.fill") }
                .tag(0)

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
            .tabItem { Label("Scan", systemImage: "doc.text.viewfinder") }
            .tag(1)

            ShoppingListView(
                store: inventoryStore,
                lowStockService: container.lowStockService,
                isAuthenticated: sessionStore.isAuthenticated,
                isGoogleAccount: sessionStore.authProvider == .google,
                profileImageURL: sessionStore.userAvatarURL,
                onOpenAccount: { showQuickAccountSheet = true }
            )
            .tabItem { Label("Einkaufsliste", systemImage: "cart.fill") }
            .tag(2)

            InsightsView(
                store: inventoryStore,
                isAuthenticated: sessionStore.isAuthenticated,
                isGoogleAccount: sessionStore.authProvider == .google,
                profileImageURL: sessionStore.userAvatarURL,
                onOpenAccount: { showQuickAccountSheet = true }
            )
                .tabItem { Label("Übersicht", systemImage: "chart.bar.fill") }
                .tag(3)

            SettingsView(
                sessionStore: sessionStore,
                notificationManager: container.notificationManager
            )
            .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
            .tag(4)
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
}

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
                Circle().stroke(AppColors.cardStroke, lineWidth: 0.5)
            }
        } else {
            Image(systemName: "person.crop.circle")
                .font(.title3.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}

private struct QuickAccountSheet: View {
    let sessionStore: SessionStore
    let onOpenAccount: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppBackgroundView {
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
