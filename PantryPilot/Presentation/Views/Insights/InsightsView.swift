import SwiftUI
import SwiftData

struct InsightsView: View {
    @State private var viewModel: InsightsViewModel
    @Query(sort: \PersistedReceipt.date, order: .reverse) private var allReceipts: [PersistedReceipt]
    @State private var showAllReceipts = false
    let isAuthenticated: Bool
    let isGoogleAccount: Bool
    let profileImageURL: String?
    let onOpenAccount: () -> Void

    init(
        store: InventoryStore,
        isAuthenticated: Bool = false,
        isGoogleAccount: Bool = false,
        profileImageURL: String? = nil,
        onOpenAccount: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: InsightsViewModel(store: store))
        self.isAuthenticated = isAuthenticated
        self.isGoogleAccount = isGoogleAccount
        self.profileImageURL = profileImageURL
        self.onOpenAccount = onOpenAccount
    }

    var body: some View {
        NavigationStack {
            AppBackgroundView {
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        metricCards
                        statusCard

                        if !viewModel.useFirstItems.isEmpty {
                            useFirstSection
                        }

                        spendingSection
                        recentReceiptsSection

                        locationCard
                        categoryCard
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.s)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("Übersicht")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileToolbarButton(
                        isAuthenticated: isAuthenticated,
                        isGoogleAccount: isGoogleAccount,
                        profileImageURL: profileImageURL,
                        action: onOpenAccount
                    )
                }
            }
            .navigationDestination(isPresented: $showAllReceipts) {
                ReceiptHistoryView()
            }
            .sheet(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
        }
    }

    // MARK: - Metrics

    private var metricCards: some View {
        HStack(spacing: AppSpacing.m) {
            MetricTile(title: "Gesamt", value: "\(viewModel.totalItems)",
                       icon: "archivebox.fill", color: AppColors.info)
            MetricTile(title: "Bald fällig", value: "\(viewModel.expiringSoon)",
                       icon: "exclamationmark.triangle.fill", color: AppColors.warning)
            MetricTile(title: "Abgelaufen", value: "\(viewModel.expired)",
                       icon: "xmark.circle.fill", color: AppColors.danger)
        }
    }

    // MARK: - Status

    private var statusCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack(spacing: AppSpacing.m) {
                    AppIconBadge(
                        icon: viewModel.expiringSoon > 0 ? "clock.badge.exclamationmark" : "checkmark.seal.fill",
                        color: viewModel.expiringSoon > 0 ? AppColors.warning : AppColors.success,
                        size: 36
                    )
                    Text(viewModel.expiringSoonLabel)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textPrimary)
                }
                Divider()
                HStack(spacing: AppSpacing.m) {
                    AppIconBadge(
                        icon: viewModel.expired > 0 ? "xmark.circle" : "checkmark.circle",
                        color: viewModel.expired > 0 ? AppColors.danger : AppColors.success,
                        size: 36
                    )
                    Text(viewModel.expiredLabel)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    // MARK: - Use First

    private var useFirstSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Zuerst verwenden", icon: "flame.fill", iconColor: AppColors.warning)

            VStack(spacing: AppSpacing.s) {
                ForEach(viewModel.useFirstItems) { item in
                    AppCard(padding: AppSpacing.m) {
                        HStack(spacing: AppSpacing.m) {
                            AppIconBadge(
                                icon: AppColors.categoryIcon(for: item.category),
                                color: AppColors.categoryColor(for: item.category),
                                size: 36
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DisplayNameFormatter.format(item.canonicalName))
                                    .font(AppTypography.bodyMedium)
                                Text(quantityText(for: item))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                            AppPillBadge(text: item.expiryStatus.shortLabel, color: item.expiryStatus.color)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Location Breakdown

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Nach Lagerort", icon: "mappin.circle.fill")

            AppCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.itemsByLocation.enumerated()), id: \.element.0) { index, entry in
                        HStack {
                            Label(entry.0.displayName, systemImage: entry.0.icon)
                                .font(AppTypography.callout)
                            Spacer()
                            Text("\(entry.1)")
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.vertical, AppSpacing.s)
                        if index < viewModel.itemsByLocation.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Category Breakdown

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Nach Kategorie", icon: "tag.fill")

            if viewModel.itemsByCategory.isEmpty {
                AppCard {
                    Text("Keine Daten")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                AppCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.itemsByCategory.enumerated()), id: \.element.0) { index, entry in
                            HStack(spacing: AppSpacing.m) {
                                AppIconBadge(
                                    icon: AppColors.categoryIcon(for: entry.0),
                                    color: AppColors.categoryColor(for: entry.0),
                                    size: 32
                                )
                                Text(entry.0.displayName)
                                    .font(AppTypography.callout)
                                Spacer()
                                Text("\(entry.1)")
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(.vertical, AppSpacing.xs)
                            if index < viewModel.itemsByCategory.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Spending

    private var spendingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Ausgaben", icon: "chart.line.uptrend.xyaxis", iconColor: AppColors.primary)

            HStack(alignment: .top, spacing: AppSpacing.m) {
                MetricTile(
                    title: "Diesen Monat",
                    value: formattedCHF(currentMonthSpending),
                    icon: "calendar",
                    color: AppColors.primary
                )
                MetricTile(
                    title: "Einkäufe",
                    value: "\(currentMonthReceiptCount)",
                    icon: "bag.fill",
                    color: AppColors.info
                )
                MetricTile(
                    title: "Ø pro Einkauf",
                    value: currentMonthReceiptCount > 0
                        ? formattedCHF(currentMonthSpending / Double(currentMonthReceiptCount))
                        : "–",
                    icon: "equal.circle.fill",
                    color: AppColors.success
                )
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Recent Receipts

    private var recentReceiptsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(
                title: "Letzte Kassenzettel",
                icon: "doc.text.fill",
                trailing: allReceipts.count > 3 ? "Alle anzeigen" : nil,
                trailingAction: { showAllReceipts = true }
            )

            if allReceipts.isEmpty {
                AppCard {
                    HStack(spacing: AppSpacing.m) {
                        Image(systemName: "doc.text")
                            .font(.title3)
                            .foregroundStyle(AppColors.textTertiary)
                        Text("Noch keine Kassenzettel gescannt")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                AppCard {
                    VStack(spacing: 0) {
                        ForEach(Array(recentReceipts.enumerated()), id: \.element.receiptId) { index, receipt in
                            receiptRow(receipt)

                            if index < recentReceipts.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
    }

    @State private var selectedReceipt: Receipt?

    private func receiptRow(_ receipt: PersistedReceipt) -> some View {
        Button {
            selectedReceipt = receipt.toDomain()
        } label: {
            HStack(spacing: AppSpacing.m) {
                AppIconBadge(icon: "bag.fill", color: AppColors.primary, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(receipt.merchant)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(receipt.itemCount) Artikel · \(formattedDate(receipt.date))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if let total = receipt.totalAmount, total > 0 {
                    Text(String(format: "CHF %.2f", total))
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.vertical, AppSpacing.s)
        }
        .buttonStyle(.plain)
    }

    private var recentReceipts: [PersistedReceipt] {
        Array(allReceipts.prefix(3))
    }

    private var currentMonthSpending: Double {
        let cal = Calendar.current
        let now = Date()
        return allReceipts
            .filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
            .compactMap(\.totalAmount)
            .reduce(0, +)
    }

    private var currentMonthReceiptCount: Int {
        let cal = Calendar.current
        let now = Date()
        return allReceipts.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Helpers

    private func formattedCHF(_ amount: Double) -> String {
        if amount >= 100 {
            return String(format: "%.0f CHF", amount)
        }
        return String(format: "%.2f CHF", amount)
    }

    private func quantityText(for item: InventoryItem) -> String {
        let qty = item.quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", item.quantity)
            : String(format: "%.1f", item.quantity)
        return "\(qty) \(item.unit)"
    }
}

// MARK: - Metric Tile

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        AppCard(padding: AppSpacing.m) {
            VStack(spacing: AppSpacing.s) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(value)
                    .font(AppTypography.metric)
                    .foregroundStyle(AppColors.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(title)
                    .font(AppTypography.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
