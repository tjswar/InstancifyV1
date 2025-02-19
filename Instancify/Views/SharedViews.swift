import SwiftUI

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.accentColor)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        BulletPoint("Example bullet point")
        BulletPoint("Another bullet point")
        BulletPoint("Third bullet point")
    }
    .padding()
} 