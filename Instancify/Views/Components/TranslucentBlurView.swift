import SwiftUI

// For general translucent blur effects
struct TranslucentMaterialView: View {
    var style: UIBlurEffect.Style = .systemMaterial
    var cornerRadius: CGFloat = 0
    
    var body: some View {
        if #available(iOS 15.0, *) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .cornerRadius(cornerRadius)
        } else {
            LegacyBlurView(style: style)
                .cornerRadius(cornerRadius)
        }
    }
}

private struct LegacyBlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct TranslucentMaterialView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.blue, .purple]), 
                         startPoint: .top, 
                          endPoint: .bottom)
                .ignoresSafeArea()
            
            TranslucentMaterialView()
                .frame(width: 200, height: 200)
                .cornerRadius(20)
        }
    }
} 