import WidgetKit
import SwiftUI
import Intents

struct InstanceEntry: TimelineEntry {
    let date: Date
    let instanceId: String
    let instanceName: String
    let state: String
    let currentCost: Double
    let projectedDailyCost: Double
    let configuration: InstancifyWidgetConfigurationIntent
}

struct Provider: IntentTimelineProvider {
    typealias Entry = InstanceEntry
    typealias Intent = InstancifyWidgetConfigurationIntent
    
    func placeholder(in context: Context) -> InstanceEntry {
        InstanceEntry(
            date: Date(),
            instanceId: "i-example",
            instanceName: "Example Instance",
            state: "stopped",
            currentCost: 0.0,
            projectedDailyCost: 0.0,
            configuration: InstancifyWidgetConfigurationIntent()
        )
    }

    func getSnapshot(for configuration: InstancifyWidgetConfigurationIntent, in context: Context, completion: @escaping (InstanceEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(for configuration: InstancifyWidgetConfigurationIntent, in context: Context, completion: @escaping (Timeline<InstanceEntry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.tech.md.Instancify")
        guard let data = sharedDefaults?.data(forKey: "widget-data"),
              let entry = try? JSONDecoder().decode(InstanceEntry.self, from: data) else {
            // Return placeholder if no data
            let entry = placeholder(in: context)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
            return
        }
        
        // Create a new entry with the configuration
        let configuredEntry = InstanceEntry(
            date: entry.date,
            instanceId: entry.instanceId,
            instanceName: entry.instanceName,
            state: entry.state,
            currentCost: entry.currentCost,
            projectedDailyCost: entry.projectedDailyCost,
            configuration: configuration
        )
        
        let timeline = Timeline(entries: [configuredEntry], policy: .atEnd)
        completion(timeline)
    }
}

@main
struct InstancifyWidgets: Widget {
    let kind: String = "InstancifyWidgets"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: InstancifyWidgetConfigurationIntent.self, provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Instancify Widget")
        .description("Monitor your EC2 instances.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetView: View {
    let entry: InstanceEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            @unknown default:
                EmptyView()
            }
        }
        .if(#available(iOS 17.0, *)) { view in
            view.containerBackground(.background, for: .widget)
        }
    }
}

struct SmallWidgetView: View {
    let entry: InstanceEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.instanceName)
                .font(.headline)
                .lineLimit(1)
            
            Text(entry.state.capitalized)
                .font(.subheadline)
                .foregroundColor(entry.state == "running" ? .green : .secondary)
            
            Spacer()
            
            Text("Region: \(entry.configuration.region.displayString)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(String(format: "Cost: $%.2f", entry.currentCost))
                .font(.caption)
                .bold()
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let entry: InstanceEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.instanceName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(entry.state.capitalized)
                    .font(.subheadline)
                    .foregroundColor(entry.state == "running" ? .green : .secondary)
                
                Text("Region: \(entry.configuration.region.displayString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Current Cost")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "$%.2f", entry.currentCost))
                    .font(.title2)
                    .bold()
                
                Text(String(format: "Projected: $%.2f/day", entry.projectedDailyCost))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct LargeWidgetView: View {
    let entry: InstanceEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.instanceName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("Region: \(entry.configuration.region.displayString)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(entry.state.capitalized)
                    .font(.subheadline)
                    .padding(6)
                    .background(entry.state == "running" ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "$%.2f", entry.currentCost))
                        .font(.title)
                        .bold()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Projected Daily Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "$%.2f", entry.projectedDailyCost))
                        .font(.title2)
                        .bold()
                }
            }
            
            Spacer()
            
            Text("ID: \(entry.instanceId)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
} 