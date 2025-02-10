import SwiftUI

struct EC2InstancesView: View {
    let instances: [EC2Instance]
    
    var body: some View {
        ForEach(instances) { instance in
            EC2InstanceRow(instance: instance)
        }
    }
} 