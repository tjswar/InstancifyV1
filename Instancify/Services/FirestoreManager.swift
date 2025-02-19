import FirebaseFirestore

class FirestoreManager {
    static let shared = FirestoreManager()
    let db = Firestore.firestore()
    
    func scheduleAlert(alertID: String, instanceID: String, region: String, scheduledTime: Date) {
        // This is now handled in the transaction within RegionRuntimeAlertsView
    }
    
    func cleanupOldAlerts() {
        // Clean up old alerts
        let oldAlerts = db.collection("scheduledAlerts")
            .whereField("scheduledTime", isLessThan: Date())
            .whereField("status", isEqualTo: "pending")
        
        oldAlerts.getDocuments { (snapshot, error) in
            if let documents = snapshot?.documents {
                let batch = self.db.batch()
                for document in documents {
                    batch.updateData(["status": "completed"], forDocument: document.reference)
                }
                batch.commit()
            }
        }
    }
} 