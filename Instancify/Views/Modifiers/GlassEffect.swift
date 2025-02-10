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
                        .fill(.ultraThinMaterial)
                        .opacity(0.7)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        }
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