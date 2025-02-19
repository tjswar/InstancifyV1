import SwiftUI

struct AppIcon: View {
    var body: some View {
        Image("AppIcon") // Make sure to add the app icon to Assets.xcassets
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
} 