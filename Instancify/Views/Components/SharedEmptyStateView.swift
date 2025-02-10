import SwiftUI

struct SharedEmptyStateView: View {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "server.rack")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
} 