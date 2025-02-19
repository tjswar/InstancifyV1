import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    
    private let pages = [
        OnboardingPageData(
            title: "Welcome to Instancify",
            subtitle: "Your AWS EC2 Instance Manager",
            description: "Monitor and control your EC2 instances with ease. Start, stop, and track costs all in one place.",
            imageName: "square.grid.2x2.fill",
            accentColor: .blue
        ),
        OnboardingPageData(
            title: "Real-Time Monitoring",
            subtitle: "Stay Informed",
            description: "Get instant notifications about instance state changes, runtime alerts, and cost projections.",
            imageName: "chart.line.uptrend.xyaxis",
            accentColor: .green
        ),
        OnboardingPageData(
            title: "Cost Control",
            subtitle: "Save Money",
            description: "Track costs in real-time, set auto-stop timers, and get alerts when instances run longer than expected.",
            imageName: "dollarsign.circle.fill",
            accentColor: .orange
        ),
        OnboardingPageData(
            title: "Secure by Design",
            subtitle: "Your Data is Protected",
            description: "AWS credentials are stored securely in the iOS Keychain. We never store or transmit your sensitive data.",
            imageName: "lock.shield.fill",
            accentColor: .purple
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    pages[currentPage].accentColor.opacity(0.2),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Page control dots
                PageControl(numberOfPages: pages.count, currentPage: $currentPage)
                    .padding(.bottom)
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(pages[currentPage].accentColor)
                            .cornerRadius(14)
                    }
                    
                    if currentPage < pages.count - 1 {
                        Button("Skip", action: completeOnboarding)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

struct OnboardingPageData {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let accentColor: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPageData
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(page.accentColor)
                .symbolEffect(.bounce)
            
            VStack(spacing: 16) {
                // Title
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text(page.subtitle)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Description
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
    }
}

struct PageControl: View {
    let numberOfPages: Int
    @Binding var currentPage: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { page in
                Circle()
                    .fill(page == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(page == currentPage ? 1.2 : 1.0)
                    .animation(.spring(), value: currentPage)
            }
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
} 