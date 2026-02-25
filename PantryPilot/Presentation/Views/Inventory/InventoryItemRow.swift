import SwiftUI

struct ProductImageView: View {
    let imageUrl: String?
    let category: FoodCategory?
    let size: CGFloat

    var body: some View {
        if let urlStr = imageUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
                } else {
                    fallbackBadge
                }
            }
            .frame(width: size, height: size)
        } else {
            fallbackBadge
        }
    }

    private var fallbackBadge: some View {
        AppIconBadge(
            icon: AppColors.categoryIcon(for: category),
            color: AppColors.categoryColor(for: category),
            size: size
        )
    }
}

struct InventoryItemRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            ProductImageView(imageUrl: item.imageUrl, category: item.category, size: 42)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(DisplayNameFormatter.format(item.canonicalName))
                    .font(AppTypography.bodyMedium)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.s) {
                    Label(quantityText, systemImage: "scalemass")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    if item.opened {
                        AppPillBadge(text: "Offen", color: AppColors.info, style: .subtle)
                    }
                }
            }

            Spacer(minLength: AppSpacing.xs)

            expiryPill
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var quantityText: String {
        let qty = item.quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", item.quantity)
            : String(format: "%.1f", item.quantity)
        return "\(qty) \(item.unit)"
    }

    @ViewBuilder
    private var expiryPill: some View {
        let status = item.expiryStatus
        switch status {
        case .unknown:
            EmptyView()
        default:
            AppPillBadge(text: status.shortLabel, color: status.color)
        }
    }
}
