import SwiftUI

struct ProductImageView: View {
    let imageUrl: String?
    let category: FoodCategory?
    let size: CGFloat

    var body: some View {
        if let urlStr = imageUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    imageView(image)
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

    private func imageView(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: size - 8, height: size - 8)
            .padding(4)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
    }
}

struct InventoryItemRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(spacing: 12) {
            ProductImageView(imageUrl: item.imageUrl, category: item.category, size: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.expiryStatus.color)
                        .frame(width: 7, height: 7)
                    Text(DisplayNameFormatter.format(item.canonicalName))
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                }

                Text(item.location.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text(quantityText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if item.opened {
                        Text("· Offen")
                            .font(.caption2)
                            .foregroundStyle(AppColors.info)
                    }
                    if item.expiryStatus != .unknown {
                        Text("· \(item.expiryStatus.shortLabel)")
                            .font(.caption2)
                            .foregroundStyle(item.expiryStatus.color)
                    }
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var quantityText: String {
        let qty = item.quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", item.quantity)
            : String(format: "%.1f", item.quantity)
        return "\(qty) \(item.unit)"
    }
}
