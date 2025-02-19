import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject private var appLockService: AppLockService
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    @State private var pin = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isShaking = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Lock icon
            Circle()
                .fill(appearanceViewModel.currentAccentColor.opacity(0.1))
                .frame(width: 100, height: 100)
                .overlay {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(appearanceViewModel.currentAccentColor)
                }
            
            VStack(spacing: 16) {
                Text("Enter PIN")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // PIN entry field
                SecureField("PIN", text: $pin)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 120)
                    .multilineTextAlignment(.center)
                    .onChange(of: pin) { oldValue, newValue in
                        // Limit to 4 digits
                        if newValue.count > 4 {
                            pin = String(newValue.prefix(4))
                        }
                        // Try to unlock when 4 digits are entered
                        if newValue.count == 4 {
                            attemptUnlock()
                        }
                    }
                    .modifier(ShakeEffect(shakes: isShaking ? 2 : 0))
            }
            
            // Unlock button
            Button {
                attemptUnlock()
            } label: {
                Text("Unlock")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(width: 200, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(appearanceViewModel.currentAccentColor)
                    )
            }
            .disabled(pin.isEmpty)
            .opacity(pin.isEmpty ? 0.6 : 1)
        }
        .padding(32)
        .background(Color(.systemBackground))
        .alert("Incorrect PIN", isPresented: $showError) {
            Button("OK", role: .cancel) {
                pin = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func attemptUnlock() {
        if appLockService.unlock(with: pin) {
            pin = ""
        } else {
            errorMessage = "Please try again"
            showError = true
            withAnimation(.default) {
                isShaking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isShaking = false
                }
            }
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakes: Int = 3
    var animatableData: CGFloat
    
    init(amount: CGFloat = 10, shakes: Int = 3) {
        self.amount = amount
        self.shakes = shakes
        self.animatableData = CGFloat(shakes)
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * 2)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

#Preview {
    LockScreenView()
        .environmentObject(AppLockService.shared)
        .environmentObject(AppearanceSettingsViewModel.shared)
} 