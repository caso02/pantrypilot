import SwiftUI

struct AppBackgroundView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            LinearGradient(
                colors: [
                    AppColors.primary.opacity(0.04),
                    Color.clear,
                    AppColors.primary.opacity(0.02),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content()
        }
    }
}
