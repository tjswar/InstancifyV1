import SwiftUI

struct InfoButton: View {
    let message: String
    @State private var showingTooltip = false
    
    var body: some View {
        Button {
            showingTooltip.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .font(.footnote)
        }
        .popover(isPresented: $showingTooltip) {
            Text(message)
                .font(.callout)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }
}