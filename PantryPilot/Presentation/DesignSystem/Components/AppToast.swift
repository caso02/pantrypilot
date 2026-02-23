import SwiftUI

struct AppToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    var icon: String = "checkmark.circle.fill"
    var undoAction: (() -> Void)? = nil
    var duration: TimeInterval = 3

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isPresented {
                toastView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, AppSpacing.xxl + 60)
                    .padding(.horizontal, AppSpacing.l)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.spring(response: 0.4)) { isPresented = false }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
    }

    private var toastView: some View {
        HStack(spacing: AppSpacing.m) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(AppTypography.callout)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            if let undoAction {
                Button("Rückgängig") {
                    Haptics.light()
                    undoAction()
                    withAnimation { isPresented = false }
                }
                .font(AppTypography.captionMedium)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xs)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .background(Capsule().fill(Color(.darkGray).opacity(0.85)))
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }
}

extension View {
    func appToast(isPresented: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill", undoAction: (() -> Void)? = nil) -> some View {
        modifier(AppToastModifier(isPresented: isPresented, message: message, icon: icon, undoAction: undoAction))
    }
}
