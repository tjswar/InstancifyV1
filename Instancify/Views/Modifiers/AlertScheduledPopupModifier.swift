import SwiftUI

struct AlertScheduledPopupModifier: ViewModifier {
    @State private var isShowingPopup = false
    @State private var instanceName = ""
    @State private var alertTimes = ""
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isShowingPopup {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    AlertScheduledPopupView(
                        instanceName: instanceName,
                        alertTimes: alertTimes
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: isShowingPopup)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAlertScheduledPopup"))) { notification in
                guard let userInfo = notification.userInfo,
                      let instanceName = userInfo["instanceName"] as? String,
                      let alertTimes = userInfo["alertTimes"] as? String else {
                    return
                }
                
                self.instanceName = instanceName
                self.alertTimes = alertTimes
                self.isShowingPopup = true
                
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.isShowingPopup = false
                }
            }
    }
}

extension View {
    func alertScheduledPopup() -> some View {
        modifier(AlertScheduledPopupModifier())
    }
} 