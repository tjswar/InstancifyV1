import SwiftUI

struct ConfirmationDialog: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let primaryButtonRole: ButtonRole?
    let primaryAction: () -> Void
    @Binding var isPresented: Bool
    @State private var offset: CGFloat = 30
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black
                .opacity(opacity * 0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Dialog content
            VStack(spacing: 24) {
                // Title and message
                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Action buttons
                HStack(spacing: 24) {
                    // Cancel button
                    ConfirmActionButton(
                        icon: "xmark",
                        title: "Cancel",
                        color: .red
                    ) {
                        HapticManager.impact(.medium)
                        dismiss()
                    }
                    
                    // Confirm button
                    ConfirmActionButton(
                        icon: "checkmark",
                        title: primaryButtonTitle,
                        color: .green
                    ) {
                        HapticManager.impact(.medium)
                        dismiss {
                            primaryAction()
                        }
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
            )
            .padding(.horizontal, 40)
            .offset(y: offset)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                offset = 0
                opacity = 1
            }
        }
    }
    
    private func dismiss(completion: (() -> Void)? = nil) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            offset = 30
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
            completion?()
        }
    }
}

private struct ConfirmActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(color)
                            .shadow(color: color.opacity(0.4), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
                    )
                    .scaleEffect(isPressed ? 0.95 : 1)
                
                Text(title)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }
}

// Add this extension for press events
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}