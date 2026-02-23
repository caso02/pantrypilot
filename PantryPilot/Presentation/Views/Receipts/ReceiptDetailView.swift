import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppBackgroundView {
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        headerCard
                        itemsCard

                        if let total = receipt.totalAmount, total > 0 {
                            totalCard(total)
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.s)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("Kassenzettel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        AppCard {
            HStack(spacing: AppSpacing.l) {
                AppIconBadge(icon: "bag.fill", color: AppColors.primary, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(receipt.merchant)
                        .font(AppTypography.headline2)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(formattedDate)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(receipt.itemCount) Artikel")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }

                Spacer()

                if let total = receipt.totalAmount, total > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(formattedPrice(total))
                            .font(AppTypography.headline2)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Items

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Artikel", icon: "list.bullet")

            AppCard {
                VStack(spacing: 0) {
                    ForEach(Array(receipt.lineItems.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: AppSpacing.m) {
                            AppIconBadge(
                                icon: AppColors.categoryIcon(for: item.category),
                                color: AppColors.categoryColor(for: item.category),
                                size: 32
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(DisplayNameFormatter.format(item.name))
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(quantityText(item))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            Spacer()

                            if let price = item.totalPrice {
                                Text(formattedPrice(price))
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                        }
                        .padding(.vertical, AppSpacing.s)

                        if index < receipt.lineItems.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Total

    private func totalCard(_ total: Double) -> some View {
        AppCard {
            HStack {
                Text("Gesamtbetrag")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(formattedPrice(total))
                    .font(AppTypography.headline2)
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: receipt.date)
    }

    private func formattedPrice(_ amount: Double) -> String {
        String(format: "CHF %.2f", amount)
    }

    private func quantityText(_ item: ReceiptLineItem) -> String {
        let qty = item.quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", item.quantity)
            : String(format: "%.1f", item.quantity)
        var text = "\(qty) \(item.unit)"
        if let unitPrice = item.unitPrice {
            text += " · CHF \(String(format: "%.2f", unitPrice))/Stk"
        }
        return text
    }
}
