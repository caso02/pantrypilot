import SwiftUI
import SwiftData

struct InsightsView: View {
    @State private var viewModel: InsightsViewModel
    @Query(sort: \PersistedReceipt.date, order: .reverse) private var allReceipts: [PersistedReceipt]
    @State private var showAllReceipts = false
    @State private var selectedReceipt: Receipt?
    var selectedTab: Binding<Int>
    let isAuthenticated: Bool
    let isGoogleAccount: Bool
    let profileImageURL: String?
    let onOpenAccount: () -> Void

    init(
        store: InventoryStore,
        selectedTab: Binding<Int> = .constant(3),
        isAuthenticated: Bool = false,
        isGoogleAccount: Bool = false,
        profileImageURL: String? = nil,
        onOpenAccount: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: InsightsViewModel(store: store))
        self.selectedTab = selectedTab
        self.isAuthenticated = isAuthenticated
        self.isGoogleAccount = isGoogleAccount
        self.profileImageURL = profileImageURL
        self.onOpenAccount = onOpenAccount
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        dashboardHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 16)

                        VStack(spacing: 20) {
                            spendingCard
                                .padding(.horizontal, 16)

                            expiryAlertsSection
                                .padding(.top, 4)

                            quickActionsSection
                                .padding(.horizontal, 16)

                            recentActivitySection
                                .padding(.horizontal, 16)

                            Spacer(minLength: 20)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showAllReceipts) {
                ReceiptHistoryView()
            }
            .sheet(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
        }
    }

    // MARK: - Header

    private var dashboardHeader: some View {
        HStack(spacing: 12) {
            ProfileToolbarButton(
                isAuthenticated: isAuthenticated,
                isGoogleAccount: isGoogleAccount,
                profileImageURL: profileImageURL,
                action: onOpenAccount
            )
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text("Übersicht")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Dashboard")
                    .font(.title3.bold())
            }

            Spacer()

            Button {
                // Notifications placeholder
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Spending Card

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monatliche Ausgaben")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formattedCHF(currentMonthSpending))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                if currentMonthReceiptCount > 0 {
                    Text("\(currentMonthReceiptCount) Einkäufe")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.primary.opacity(0.12))
                        .foregroundStyle(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            miniBarChart

            Divider()
                .overlay(AppColors.primary.opacity(0.1))

            HStack {
                Text("Basierend auf \(currentMonthReceiptCount) Einkäufen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if allReceipts.count > 3 {
                    Button {
                        showAllReceipts = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Analytik")
                            Image(systemName: "chart.line.uptrend.xyaxis")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var miniBarChart: some View {
        HStack(alignment: .bottom, spacing: 4) {
            let heights: [CGFloat] = monthlyBarHeights
            ForEach(0..<heights.count, id: \.self) { i in
                let isLast = i == heights.count - 1
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isLast ? AppColors.primary : AppColors.primary.opacity(0.25 + CGFloat(i) * 0.1))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(6, heights[i] * 56))
            }
        }
        .frame(height: 56)
        .padding(.vertical, 4)
    }

    private var monthlyBarHeights: [CGFloat] {
        guard !allReceipts.isEmpty else {
            return Array(repeating: 0.3, count: 7)
        }
        let cal = Calendar.current
        var monthlySums: [CGFloat] = []
        for offset in (-6...0) {
            let date = cal.date(byAdding: .month, value: offset, to: Date()) ?? Date()
            let sum = allReceipts
                .filter { cal.isDate($0.date, equalTo: date, toGranularity: .month) }
                .compactMap(\.totalAmount)
                .reduce(0, +)
            monthlySums.append(CGFloat(sum))
        }
        let maxVal = monthlySums.max() ?? 1
        return maxVal > 0 ? monthlySums.map { $0 / maxVal } : monthlySums.map { _ in 0.2 }
    }

    // MARK: - Expiry Alerts

    private var expiryAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ablauf-Warnungen")
                    .font(.title3.bold())
                Spacer()
                if viewModel.expiringSoon > 0 {
                    Text("\(viewModel.expiringSoon) kritisch")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(Color.red)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)

            if viewModel.useFirstItems.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.primary)
                    Text("Kein Artikel läuft bald ab")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardStroke) }
                .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.useFirstItems.prefix(5)) { item in
                            ExpiryAlertCard(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schnellaktionen")
                .font(.title3.bold())

            HStack(spacing: 12) {
                QuickActionButton(icon: "doc.text.viewfinder", label: "Scannen") {
                    selectedTab.wrappedValue = 1
                }
                QuickActionButton(icon: "cart.fill", label: "Einkaufsliste") {
                    selectedTab.wrappedValue = 2
                }
                QuickActionButton(icon: "refrigerator.fill", label: "Inventar") {
                    selectedTab.wrappedValue = 0
                }
            }
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Letzte Kassenzettel")
                    .font(.title3.bold())
                Spacer()
                if allReceipts.count > 3 {
                    Button("Alle anzeigen") { showAllReceipts = true }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                        .buttonStyle(.plain)
                }
            }

            if allReceipts.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.tertiary)
                    Text("Noch keine Kassenzettel gescannt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardStroke) }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentReceipts.enumerated()), id: \.element.receiptId) { index, receipt in
                        receiptRow(receipt)
                        if index < recentReceipts.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardStroke) }
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }
        }
    }

    private func receiptRow(_ receipt: PersistedReceipt) -> some View {
        Button {
            selectedReceipt = receipt.toDomain()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(receipt.merchant)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(receipt.itemCount) Artikel · \(formattedDate(receipt.date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let total = receipt.totalAmount, total > 0 {
                    Text(String(format: "CHF %.2f", total))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

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

    private func formattedCHF(_ amount: Double) -> String {
        if amount >= 100 {
            return String(format: "%.0f CHF", amount)
        }
        return String(format: "%.2f CHF", amount)
    }
}

// MARK: - Expiry Alert Card

private struct ExpiryAlertCard: View {
    let item: InventoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ProductImageView(imageUrl: item.imageUrl, category: item.category, size: 100)
                    .frame(width: 116, height: 100, alignment: .center)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.92))
                        .frame(width: 26, height: 26)
                    Image(systemName: item.expiryStatus.isExpired ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(item.expiryStatus.color)
                }
                .padding(6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(DisplayNameFormatter.format(item.canonicalName))
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text(item.expiryStatus.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item.expiryStatus.color)
            }
        }
        .padding(10)
        .frame(width: 140)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardStroke) }
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.black)
                    }
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(AppColors.primary.opacity(0.2)) }
        }
        .buttonStyle(.plain)
    }
}
