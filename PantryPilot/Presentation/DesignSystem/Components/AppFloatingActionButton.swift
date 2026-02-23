import SwiftUI

struct AppFloatingActionButton: View {
    let icon: String
    var color: Color = AppColors.primary
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(color, in: Circle())
                .shadow(color: color.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(FABButtonStyle())
        .padding(.trailing, AppSpacing.l + 4)
        .padding(.bottom, AppSpacing.l + 4)
    }
}

private struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
