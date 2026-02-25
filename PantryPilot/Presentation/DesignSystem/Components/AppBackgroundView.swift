import SwiftUI

struct AppBackgroundView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            content()
        }
    }
}
