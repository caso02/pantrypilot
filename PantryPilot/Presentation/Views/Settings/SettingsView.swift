import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(sessionStore: SessionStore, notificationManager: NotificationManager) {
        _viewModel = State(initialValue: SettingsViewModel(
            sessionStore: sessionStore,
            notificationManager: notificationManager
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            AppBackgroundView {
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        notificationsSection
                        privacySection
                        accountSection
                        developerSection
                        infoSection
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.s)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("Einstellungen")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Benachrichtigungen", icon: "bell.fill", iconColor: AppColors.primary)

            AppCard {
                Toggle(isOn: $viewModel.notificationsEnabled) {
                    HStack(spacing: AppSpacing.m) {
                        AppIconBadge(icon: "bell.badge.fill", color: AppColors.primary, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ablauf-Erinnerungen")
                                .font(AppTypography.bodyMedium)
                            Text("Benachrichtigung wenn Artikel bald ablaufen")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }
                .onChange(of: viewModel.notificationsEnabled) { _, enabled in
                    if enabled { Task { await viewModel.requestNotificationPermission() } }
                }
            }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Datenschutz", icon: "lock.fill", iconColor: AppColors.info)

            AppCard {
                Toggle(isOn: $viewModel.privacyMode) {
                    HStack(spacing: AppSpacing.m) {
                        AppIconBadge(icon: "eye.slash.fill", color: AppColors.info, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privater Modus")
                                .font(AppTypography.bodyMedium)
                            Text("Keine Daten an den Server senden")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Account

    @State private var showSignOutConfirm = false

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Konto", icon: "person.fill")

            if viewModel.isAuthenticated {
                AppCard {
                    VStack(spacing: 0) {
                        HStack(spacing: AppSpacing.m) {
                            AppIconBadge(icon: "person.crop.circle.fill", color: AppColors.primary, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.userName ?? "Apple-Benutzer")
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary)
                                if let email = viewModel.userEmail {
                                    Text(email)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                            Spacer()
                            AppPillBadge(text: "Apple ID", color: AppColors.textSecondary, style: .subtle)
                        }
                        .padding(.bottom, AppSpacing.m)

                        Divider()

                        Button {
                            Haptics.warning()
                            showSignOutConfirm = true
                        } label: {
                            HStack(spacing: AppSpacing.m) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppColors.danger)
                                Text("Abmelden")
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.danger)
                                Spacer()
                            }
                            .padding(.top, AppSpacing.m)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .alert("Abmelden?", isPresented: $showSignOutConfirm) {
                    Button("Abbrechen", role: .cancel) {}
                    Button("Abmelden", role: .destructive) { viewModel.signOut() }
                } message: {
                    Text("Lokale Daten bleiben erhalten. Du kannst dich jederzeit wieder anmelden.")
                }
            } else {
                AppCard {
                    HStack(spacing: AppSpacing.m) {
                        AppIconBadge(icon: "icloud.slash.fill", color: AppColors.textTertiary, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cloud-Sync nicht verfügbar")
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(AppColors.textPrimary)
                            Text("Erfordert Apple Developer Program")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Developer

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Entwickler", icon: "hammer.fill", iconColor: AppColors.textTertiary)

            AppCard {
                VStack(spacing: AppSpacing.m) {
                    Toggle(isOn: $viewModel.useMockAPI) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mock API")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.textSecondary)
                            Text("Simulierte API-Antworten")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    .tint(AppColors.textSecondary)

                    Divider()

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Backend URL")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                        TextField("http://192.168.1.61:3000", text: $viewModel.backendURL)
                            .font(AppTypography.callout)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                }
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        AppCard {
            HStack {
                HStack(spacing: AppSpacing.m) {
                    AppIconBadge(icon: "info.circle.fill", color: AppColors.textTertiary, size: 36)
                    Text("Version")
                        .font(AppTypography.callout)
                }
                Spacer()
                Text(viewModel.appVersion)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

}
