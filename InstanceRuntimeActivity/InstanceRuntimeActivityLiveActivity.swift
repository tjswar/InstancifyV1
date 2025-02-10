//
//  InstanceRuntimeActivityLiveActivity.swift
//  InstanceRuntimeActivity
//
//  Created by Dalli Sai Tejaswar Reddy on 1/28/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct InstanceRuntimeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct InstanceRuntimeActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InstanceRuntimeActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension InstanceRuntimeActivityAttributes {
    fileprivate static var preview: InstanceRuntimeActivityAttributes {
        InstanceRuntimeActivityAttributes(name: "World")
    }
}

extension InstanceRuntimeActivityAttributes.ContentState {
    fileprivate static var smiley: InstanceRuntimeActivityAttributes.ContentState {
        InstanceRuntimeActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: InstanceRuntimeActivityAttributes.ContentState {
         InstanceRuntimeActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: InstanceRuntimeActivityAttributes.preview) {
   InstanceRuntimeActivityLiveActivity()
} contentStates: {
    InstanceRuntimeActivityAttributes.ContentState.smiley
    InstanceRuntimeActivityAttributes.ContentState.starEyes
}
