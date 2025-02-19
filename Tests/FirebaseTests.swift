import XCTest
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
@testable import Instancify

class FirebaseTests: XCTestCase {
    let notificationSettings = NotificationSettingsViewModel.shared
    let testRegion = "test-region-1"
    
    override class func setUp() {
        super.setUp()
        FirebaseApp.configure() // Ensure Firebase is initialized for tests
    }
    
    override func setUp() async throws {
        // Clean up any existing data
        try await cleanupTestData()
    }
    
    override func tearDown() async throws {
        // Clean up after tests
        try await cleanupTestData()
    }
    
    func testAuthenticationAndAlerts() async throws {
        // Test 1: Authentication
        XCTAssertNil(Auth.auth().currentUser, "Should start unauthenticated")
        
        // Enable alerts for region
        try await notificationSettings.setRuntimeAlerts(enabled: true, for: testRegion)
        
        // Verify authentication worked
        XCTAssertNotNil(Auth.auth().currentUser, "Should be authenticated")
        
        // Test 2: Firestore Write
        let db = Firestore.firestore()
        let doc = try await db.collection("regionAlertStatus")
            .document(testRegion)
            .getDocument()
        
        XCTAssertTrue(doc.exists)
        XCTAssertEqual(doc.data()?["enabled"] as? Bool, true)
        
        // Test 3: Add Runtime Alert
        notificationSettings.addNewAlert(
            hours: 1,
            minutes: 30,
            regions: Set([testRegion])
        )
        
        // Wait for Firestore operation
        try await waitForFirestore()
        
        let alerts = try await db.collection("scheduledAlerts")
            .whereField("region", isEqualTo: testRegion)
            .getDocuments()
        
        XCTAssertFalse(alerts.documents.isEmpty)
        
        // Test 4: Disable Alerts
        try await notificationSettings.setRuntimeAlerts(enabled: false, for: testRegion)
        
        let alertsAfterDisable = try await db.collection("scheduledAlerts")
            .whereField("region", isEqualTo: testRegion)
            .getDocuments()
        
        XCTAssertTrue(alertsAfterDisable.documents.isEmpty)
    }
    
    private func cleanupTestData() async throws {
        let db = Firestore.firestore()
        
        // Clear test region status
        try await db.collection("regionAlertStatus")
            .document(testRegion)
            .delete()
        
        // Clear test alerts
        let alerts = try await db.collection("scheduledAlerts")
            .whereField("region", isEqualTo: testRegion)
            .getDocuments()
        
        for doc in alerts.documents {
            try await doc.reference.delete()
        }
        
        // Sign out
        try Auth.auth().signOut()
    }
    
    private func waitForFirestore() async throws {
        // Wait for Firestore operations to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
} 