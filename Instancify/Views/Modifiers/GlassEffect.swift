import SwiftUI

// Simplified GlassBlurView
struct GlassBlurView: View {
    var style: UIBlurEffect.Style = .systemMaterial
    var cornerRadius: CGFloat = 20
    
    var body: some View {
        TranslucentMaterialView(style: style)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct GlassEffect: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial.opacity(0.6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    Color.white.opacity(0.04),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial.opacity(0.5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    Color.white.opacity(0.1),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
                }
            }
    }
}

extension View {
    func glassEffect() -> some View {
        modifier(GlassEffect())
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .purple], 
                     startPoint: .top, 
                     endPoint: .bottom)
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            Text("Glass Effect")
                .foregroundColor(.white)
                .padding()
                .glassEffect()
            
            Text("Another Card")
                .foregroundColor(.white)
                .padding()
                .glassEffect()
        }
    }
    .preferredColorScheme(.dark)
} 