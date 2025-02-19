import WidgetKit
import SwiftUI
import Intents

// MARK: - Configuration
enum WidgetUI {
    struct Sizes {
        static let statusIndicatorSize: CGFloat = 6
        static let defaultPadding: CGFloat = 16
        static let largePadding: CGFloat = 20
        static let defaultSpacing: CGFloat = 12
        static let smallSpacing: CGFloat = 4
    }
    
    struct Colors {
        static let running = Color.green
        static let stopped = Color.red
        static let projected = Color.orange
    }
}

// MARK: - Widget Entry
struct InstanceEntry: TimelineEntry {
    let date: Date
    let instances: [InstanceInfo]
    
    struct InstanceInfo {
        let instanceId: String
        let instanceName: String
        let state: String
        let runtime: Int
        let region: String
    }
    
    static func placeholder() -> InstanceEntry {
        InstanceEntry(
            date: Date(),
            instances: [
                InstanceInfo(
                    instanceId: "i-example",
                    instanceName: "Example Instance",
                    state: "running",
                    runtime: 3600,
                    region: "us-east-1"
                )
            ]
        )
    }
    
    static func from(_ data: [WidgetData]?) -> InstanceEntry {
        let instances = data?.map { widgetData in
            InstanceInfo(
                instanceId: widgetData.instanceId,
                instanceName: widgetData.instanceName,
                state: widgetData.state,
                runtime: widgetData.runtime,
                region: widgetData.region
            )
        } ?? []
        return InstanceEntry(
            date: Date(),
            instances: instances
        )
    }
}

// MARK: - Helper Functions
private func formatRuntime(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
}

private func getCurrentRegion() -> String {
    let defaults = UserDefaults(suiteName: SharedConfig.userDefaultsSuite)
    let region = defaults?.string(forKey: SharedConfig.currentRegionKey)
    print("🌎 Widget: Using region from app: \(region ?? "us-west-2")")
    return region ?? "us-west-2"
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Widget Provider
struct Provider: TimelineProvider {
    private let refreshInterval: TimeInterval = SharedConfig.refreshInterval
    
    func placeholder(in context: Context) -> InstanceEntry {
        InstanceEntry.placeholder()
    }
    
    func getSnapshot(in context: Context, completion: @escaping (InstanceEntry) -> ()) {
        // Get current region
        let region = getCurrentRegion()
        print("📸 Widget Snapshot: Loading data for region: \(region)")
        
        // Load widget data for the region
        let widgetData = WidgetData.load(for: region)
        print("📸 Widget Snapshot: Found \(widgetData?.count ?? 0) instances")
        
        // Create entry from widget data
        let entry = InstanceEntry.from(widgetData)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<InstanceEntry>) -> ()) {
        // Get current region
        let region = getCurrentRegion()
        print("⏰ Widget Timeline: Loading data for region: \(region)")
        
        // Load widget data for the region
        let widgetData = WidgetData.load(for: region)
        print("⏰ Widget Timeline: Found \(widgetData?.count ?? 0) instances")
        
        // Create entry from widget data
        let entry = InstanceEntry.from(widgetData)
        
        // Create timeline with refresh interval
        let nextRefresh = Date().addingTimeInterval(refreshInterval)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        
        completion(timeline)
    }
}

// MARK: - Widget Views
struct HomeScreenWidgetView: View {
    let entry: InstanceEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(instances: entry.instances)
            case .systemMedium:
                MediumWidgetView(instances: entry.instances)
            case .systemLarge:
                LargeWidgetView(instances: entry.instances)
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                EmptyView()
            @unknown default:
                EmptyView()
            }
        }
        #if os(iOS)
        .modifier(ContainerBackgroundModifier())
        #endif
    }
}

private struct ContainerBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(.background, for: .widget)
        } else {
            content.background(Color(uiColor: .systemBackground))
        }
    }
}

struct SmallWidgetView: View {
    let instances: [InstanceEntry.InstanceInfo]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if instances.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No Instances")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Instance count
                HStack {
                    let runningCount = instances.filter { $0.state == "running" }.count
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .foregroundStyle(runningCount > 0 ? .green : .secondary)
                        Text("\(runningCount) running")
                            .font(.caption)
                            .foregroundStyle(runningCount > 0 ? .green : .secondary)
                    }
                    Spacer()
                    Text("\(instances.count) instances")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                
                // First instance controls
                if let firstInstance = instances.first {
                    Divider()
                        .padding(.horizontal, 8)
                    
                    HStack {
                        // Instance name
                        Text(firstInstance.instanceName)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Action button
                        if firstInstance.state == "running" {
                            Link(destination: URL(string: "instancify:///stop/\(firstInstance.instanceId)")!) {
                                Image(systemName: "stop.circle")
                                    .foregroundStyle(.red)
                            }
                        } else {
                            Link(destination: URL(string: "instancify:///start/\(firstInstance.instanceId)")!) {
                                Image(systemName: "play.circle")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .modifier(ContainerBackgroundModifier())
    }
}

struct MediumWidgetView: View {
    let instances: [InstanceEntry.InstanceInfo]
    
    var body: some View {
        VStack(spacing: WidgetUI.Sizes.smallSpacing) {
            // Header with instance counts
            HStack(alignment: .center, spacing: 4) {
                // Total instances
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(instances.count)")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Running instances
                let runningCount = instances.filter { $0.state == "running" }.count
                if runningCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "power")
                            .font(.system(.body, design: .rounded))
                        Text("\(runningCount)")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(WidgetUI.Colors.running)
                }
            }
            .widgetURL(URL(string: "instancify:///instances"))
            
            if instances.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(.title2, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.7))
                    Text("No Instances")
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Instance List
                VStack(spacing: 12) {
                    ForEach(instances.prefix(3), id: \.instanceId) { instance in
                        HStack(spacing: 8) {
                            // Status and name
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(instance.state == "running" ? WidgetUI.Colors.running : WidgetUI.Colors.stopped)
                                    .frame(width: WidgetUI.Sizes.statusIndicatorSize, height: WidgetUI.Sizes.statusIndicatorSize)
                                
                                Text(instance.instanceName)
                                    .font(.system(.callout, design: .rounded, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .widgetURL(URL(string: "instancify:///instance/\(instance.instanceId)"))
                            
                            Spacer()
                            
                            // Runtime - only show for running instances
                            if instance.state == "running" {
                                Text(formatRuntime(instance.runtime))
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Action button
                            if instance.state == "running" {
                                Link(destination: URL(string: "instancify:///stop/\(instance.instanceId)")!) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(.body, design: .rounded))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, WidgetUI.Colors.stopped)
                                }
                            } else {
                                Link(destination: URL(string: "instancify:///start/\(instance.instanceId)")!) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(.body, design: .rounded))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, WidgetUI.Colors.running)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                
                if instances.count > 3 {
                    HStack(spacing: 2) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(.caption2, design: .rounded))
                        Text("+\(instances.count - 3)")
                            .font(.system(.caption2, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(12)
        .background(Color(uiColor: .systemBackground))
    }
}

struct LargeWidgetView: View {
    let instances: [InstanceEntry.InstanceInfo]
    
    var body: some View {
        VStack(spacing: WidgetUI.Sizes.defaultSpacing) {
            // Header with minimalistic instance count
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                
                Text("\(instances.count)")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Running Count
                let runningCount = instances.filter { $0.state == "running" }.count
                if runningCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(WidgetUI.Colors.running)
                        Text("\(runningCount)")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(WidgetUI.Colors.running)
                    }
                }
            }
            
            if instances.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(.largeTitle, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("No Instances")
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("in \(getCurrentRegion())")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Divider()
                
                ForEach(instances, id: \.instanceId) { instance in
                    InstanceRowView(instance: instance)
                    if instance.instanceId != instances.last?.instanceId {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(WidgetUI.Sizes.defaultPadding)
        .background(Color(uiColor: .systemBackground))
        .widgetURL(URL(string: "instancify://instances")!)
    }
}

struct InstanceRowView: View {
    let instance: InstanceEntry.InstanceInfo
    
    var body: some View {
        HStack(spacing: WidgetUI.Sizes.defaultSpacing) {
            // Instance Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(instance.state == "running" ? WidgetUI.Colors.running : WidgetUI.Colors.stopped)
                        .frame(width: WidgetUI.Sizes.statusIndicatorSize, height: WidgetUI.Sizes.statusIndicatorSize)
                    Text(instance.instanceName)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    Text(instance.instanceId)
                        .font(.system(.caption2, design: .rounded))
                    Text("•")
                        .font(.caption2)
                    Text(instance.region)
                        .font(.system(.caption2, design: .rounded))
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Runtime & Actions
            HStack(spacing: WidgetUI.Sizes.defaultSpacing) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(.caption, design: .rounded))
                    Text(formatRuntime(instance.runtime))
                        .font(.system(.callout, design: .rounded, weight: .medium))
                }
                .foregroundStyle(.secondary)
                
                if instance.state == "running" {
                    Link(destination: URL(string: "instancify:///stop/\(instance.instanceId)")!) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(.title3, design: .rounded))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, WidgetUI.Colors.stopped)
                    }
                } else {
                    Link(destination: URL(string: "instancify:///start/\(instance.instanceId)")!) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(.title3, design: .rounded))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, WidgetUI.Colors.running)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .widgetURL(URL(string: "instancify://instance/\(instance.instanceId)")!)
    }
}

// MARK: - Widget Configuration
@main
struct InstancifyWidgets: Widget {
    let kind: String = "InstancifyWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HomeScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Instancify Widget")
        .description("Monitor your EC2 instances.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Preview
struct InstancifyWidget_Previews: PreviewProvider {
    static var previews: some View {
        let instances = [
            InstanceEntry.InstanceInfo(
                instanceId: "i-example1",
                instanceName: "Production Server",
                state: "running",
                runtime: 7200,
                region: "us-east-1"
            ),
            InstanceEntry.InstanceInfo(
                instanceId: "i-example2",
                instanceName: "Development Server",
                state: "stopped",
                runtime: 3600,
                region: "us-east-1"
            )
        ]
        
        let entry = InstanceEntry(
            date: Date(),
            instances: instances
        )
        
        Group {
            HomeScreenWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            HomeScreenWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            HomeScreenWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}

