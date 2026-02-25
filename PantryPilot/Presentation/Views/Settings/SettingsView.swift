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
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        profileSection
                            .padding(.bottom, 24)

                        VStack(spacing: 24) {
                            notificationsSection
                            accountSection
                            developerSection
                            infoSection
                            signOutButton
                        }
                        .padding(.horizontal, AppSpacing.l)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(viewModel.isAuthenticated ? AppColors.primary.opacity(0.1) : Color(.secondarySystemBackground))
                .frame(width: 96, height: 96)
                .overlay {
                    Image(systemName: viewModel.isAuthenticated ? "person.crop.circle.fill" : "person.crop.circle")
                        .font(.system(size: 52))
                        .foregroundStyle(viewModel.isAuthenticated ? AppColors.primary.opacity(0.7) : Color(.tertiaryLabel))
                }
                .overlay { Circle().stroke(AppColors.primary.opacity(viewModel.isAuthenticated ? 0.2 : 0), lineWidth: 2) }

            VStack(spacing: 4) {
                Text(viewModel.userName ?? "Benutzer")
                    .font(.title3.bold())
                if let email = viewModel.userEmail, !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !viewModel.isAuthenticated {
                    Text("Nicht angemeldet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppColors.surface)
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        settingsGroup(title: "Benachrichtigungen") {
            settingsToggle(
                icon: "bell.badge.fill",
                label: "Ablauf-Erinnerungen",
                subtitle: "Wenn Artikel bald ablaufen",
                isOn: $viewModel.notificationsEnabled
            )
            .onChange(of: viewModel.notificationsEnabled) { _, enabled in
                if enabled { Task { await viewModel.requestNotificationPermission() } }
            }
        }
    }

    // MARK: - Account

    @State private var showSignOutConfirm = false

    private var accountSection: some View {
        settingsGroup(title: "Konto") {
            if !viewModel.isAuthenticated {
                settingsInfo(icon: "icloud.slash.fill", label: "Cloud-Sync nicht verfügbar", subtitle: "Erfordert Anmeldung")
            }
        }
        .alert("Abmelden?", isPresented: $showSignOutConfirm) {
            Button("Abbrechen", role: .cancel) {}
            Button("Abmelden", role: .destructive) { viewModel.signOut() }
        } message: {
            Text("Lokale Daten bleiben erhalten.")
        }
    }

    // MARK: - Developer

    private var developerSection: some View {
        settingsGroup(title: "Entwickler") {
            Toggle(isOn: $viewModel.useMockAPI) {
                settingsRowLabel(icon: "hammer.fill", label: "Mock API", subtitle: "Simulierte API-Antworten")
            }
            .tint(AppColors.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.leading, 56)

            VStack(alignment: .leading, spacing: 6) {
                settingsRowLabel(icon: "link", label: "Backend URL", subtitle: nil)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                Picker(
                    "Backend auswählen",
                    selection: Binding(
                        get: { viewModel.selectedBackendPreset },
                        set: { viewModel.setBackendPreset($0) }
                    )
                ) {
                    ForEach(SettingsViewModel.BackendPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 16)

                if viewModel.selectedBackendPreset == .custom {
                    TextField("https://example.com", text: $viewModel.backendURL)
                        .font(.system(size: 13))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .padding(.horizontal, 16)
                } else {
                    Text(viewModel.backendURL)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 16)
                }

                Text("Änderung gilt für neue Requests; ggf. App kurz neu starten.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        settingsGroup(title: "App-Info") {
            settingsInfo(icon: "info.circle.fill", label: "Version", trailing: viewModel.appVersion)
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Group {
            if viewModel.isAuthenticated {
                Button {
                    Haptics.warning()
                    showSignOutConfirm = true
                } label: {
                    Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.red)
                }
                .background(Color.red.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Settings Group Helpers

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardStroke) }
        }
    }

    private func settingsToggle(icon: String, label: String, subtitle: String?, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            settingsRowLabel(icon: icon, label: label, subtitle: subtitle)
        }
        .tint(AppColors.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func settingsInfo(icon: String, label: String, subtitle: String? = nil, trailing: String? = nil) -> some View {
        HStack(spacing: 12) {
            settingsRowLabel(icon: icon, label: label, subtitle: subtitle)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func settingsRowLabel(icon: String, label: String, subtitle: String?) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.primary.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.primary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

}
