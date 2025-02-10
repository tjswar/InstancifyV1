import SwiftUI

struct FilteredInstancesView: View {
    let resources: [AWSResource]
    
    var body: some View {
        ForEach(resources) { resource in
            EC2InstanceRow(instance: resource.instance)
        }
    }
} 