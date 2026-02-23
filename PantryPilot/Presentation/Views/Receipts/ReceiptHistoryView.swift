import SwiftUI
import SwiftData

struct ReceiptHistoryView: View {
    @Query(sort: \PersistedReceipt.date, order: .reverse) private var receipts: [PersistedReceipt]
    @State private var selectedReceipt: Receipt?

    var body: some View {
        NavigationStack {
            AppBackgroundView {
                Group {
                    if receipts.isEmpty {
                        AppEmptyState(
                            icon: "doc.text",
                            title: "Keine Kassenzettel",
                            subtitle: "Scanne deinen ersten Kassenzettel, um die Historie zu starten."
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: AppSpacing.xl) {
                                spendingSummaryCard
                                receiptListSection
                            }
                            .padding(.horizontal, AppSpacing.l)
                            .padding(.top, AppSpacing.s)
                            .padding(.bottom, AppSpacing.xxl)
                        }
                    }
                }
            }
            .navigationTitle("Kassenzettel")
            .sheet(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
        }
    }

    // MARK: - Spending Summary

    private var spendingSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Ausgaben", icon: "chart.line.uptrend.xyaxis", iconColor: AppColors.primary)

            HStack(spacing: AppSpacing.m) {
                SpendingTile(
                    title: "Diesen Monat",
                    amount: currentMonthSpending,
                    icon: "calendar",
                    color: AppColors.primary
                )
                SpendingTile(
                    title: "Letzter Monat",
                    amount: lastMonthSpending,
                    icon: "calendar.badge.clock",
                    color: AppColors.textSecondary
                )
                SpendingTile(
                    title: "Einkäufe",
                    amount: nil,
                    count: currentMonthReceiptCount,
                    icon: "bag.fill",
                    color: AppColors.info
                )
            }
        }
    }

    // MARK: - Receipt List

    private var receiptListSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Verlauf", icon: "clock.fill")

            ForEach(groupedByMonth, id: \.key) { month, monthReceipts in
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text(month)
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.leading, AppSpacing.xs)

                    AppCard {
                        VStack(spacing: 0) {
                            ForEach(Array(monthReceipts.enumerated()), id: \.element.receiptId) { index, receipt in
                                Button {
                                    selectedReceipt = receipt.toDomain()
                                } label: {
                                    receiptRow(receipt)
                                }
                                .buttonStyle(.plain)

                                if index < monthReceipts.count - 1 {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func receiptRow(_ receipt: PersistedReceipt) -> some View {
        HStack(spacing: AppSpacing.m) {
            AppIconBadge(icon: "bag.fill", color: AppColors.primary, size: 40)

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
                Text(formattedPrice(total))
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.vertical, AppSpacing.s)
    }

    // MARK: - Computed

    private var groupedByMonth: [(key: String, value: [PersistedReceipt])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: receipts) { formatter.string(from: $0.date) }
        let ordered = grouped.sorted { first, second in
            guard let d1 = first.value.first?.date, let d2 = second.value.first?.date else { return false }
            return d1 > d2
        }
        return ordered.map { (key: $0.key, value: $0.value) }
    }

    private var currentMonthSpending: Double {
        let cal = Calendar.current
        let now = Date()
        return receipts
            .filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
            .compactMap(\.totalAmount)
            .reduce(0, +)
    }

    private var lastMonthSpending: Double {
        let cal = Calendar.current
        guard let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) else { return 0 }
        return receipts
            .filter { cal.isDate($0.date, equalTo: lastMonth, toGranularity: .month) }
            .compactMap(\.totalAmount)
            .reduce(0, +)
    }

    private var currentMonthReceiptCount: Int {
        let cal = Calendar.current
        let now = Date()
        return receipts.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    // MARK: - Formatting

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedPrice(_ amount: Double) -> String {
        String(format: "CHF %.2f", amount)
    }
}

// MARK: - Spending Tile

private struct SpendingTile: View {
    let title: String
    var amount: Double?
    var count: Int?
    let icon: String
    let color: Color

    var body: some View {
        AppCard(padding: AppSpacing.m) {
            VStack(spacing: AppSpacing.s) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                if let amount {
                    Text(String(format: "%.2f", amount))
                        .font(AppTypography.metric)
                        .foregroundStyle(AppColors.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                } else if let count {
                    Text("\(count)")
                        .font(AppTypography.metric)
                        .foregroundStyle(AppColors.textPrimary)
                }

                Text(title)
                    .font(AppTypography.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
