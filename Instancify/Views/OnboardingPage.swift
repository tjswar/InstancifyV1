import SwiftUI

struct OnboardingPage: View {
    let title: String
    let subtitle: String
    let image: String
    let buttonText: String
    var showSkip: Bool = false
    let action: () -> Void
    var onSkip: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: image)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title)
                    .bold()
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: action) {
                Text(buttonText)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            
            if showSkip {
                Button("Skip", action: { onSkip?() })
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 20)
    }
}

#Preview {
    OnboardingPage(
        title: "Welcome",
        subtitle: "Monitor your AWS resources from anywhere",
        image: "cloud.fill",
        buttonText: "Next"
    ) {
        // Action
    }
} 