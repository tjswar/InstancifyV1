import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let instances: [InstanceEntry.InstanceInfo]
    let region: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: InstancifyWidgetConfig.UI.smallSpacing) {
            // Header with instance counts
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("\(instances.count)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
                
                Text(region.replacingOccurrences(of: "us-", with: ""))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !instances.isEmpty {
                    let runningCount = instances.filter { $0.state == "running" }.count
                    if runningCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "power")
                                .font(.system(.body, design: .rounded))
                            Text("\(runningCount)")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .foregroundStyle(InstancifyWidgetConfig.Colors.running)
                    }
                }
            }
            
            if instances.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(.title2, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.7))
                    Text("No Instances")
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("in \(region)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else if let firstInstance = instances.first {
                Spacer()
                
                // Instance name with status
                HStack(spacing: 6) {
                    Circle()
                        .fill(firstInstance.state == "running" ? InstancifyWidgetConfig.Colors.running : InstancifyWidgetConfig.Colors.stopped)
                        .frame(width: InstancifyWidgetConfig.UI.statusIndicatorSize, height: InstancifyWidgetConfig.UI.statusIndicatorSize)
                    
                    Text(firstInstance.instanceName)
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                if firstInstance.state == "running" {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(formatRuntime(firstInstance.runtime))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .systemBackground))
        .widgetURL(URL(string: "instancify://instances")!)
    }
} 