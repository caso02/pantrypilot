import SwiftUI

struct LoadingSkeletonView: View {
    var lineCount: Int = 4

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        VStack(spacing: AppSpacing.l) {
            ForEach(0..<lineCount, id: \.self) { index in
                skeletonRow(widthFraction: index % 2 == 0 ? 0.85 : 0.65)
            }
        }
        .padding(AppSpacing.l)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 2
            }
        }
    }

    private func skeletonRow(widthFraction: CGFloat) -> some View {
        HStack(spacing: AppSpacing.m) {
            RoundedRectangle(cornerRadius: AppSpacing.iconBadgeRadius)
                .fill(shimmerGradient)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: widthFraction, anchor: .leading)

                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 10)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: widthFraction * 0.6, anchor: .leading)
            }
        }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemGray5),
                Color(.systemGray4).opacity(0.6),
                Color(.systemGray5),
            ],
            startPoint: UnitPoint(x: shimmerOffset - 1, y: 0.5),
            endPoint: UnitPoint(x: shimmerOffset, y: 0.5)
        )
    }
}
