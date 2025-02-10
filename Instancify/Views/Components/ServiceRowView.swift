import SwiftUI

struct ServiceRowView: View {
    let service: AWSServiceType
    let resourceCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Service Icon
            Image(systemName: service.iconName)
                .foregroundColor(service.iconColor)
                .font(.system(size: 24, weight: .medium))
                .frame(width: 40, height: 40)
                .background(
                    service.iconColor.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Service Info
            VStack(alignment: .leading, spacing: 4) {
                Text(service.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(service.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Resource Count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(resourceCount)")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(service.iconColor)
                Text("resources")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

