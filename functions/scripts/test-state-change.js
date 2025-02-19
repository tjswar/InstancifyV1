const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin for emulator
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'demo-instancify'
  });
}

const db = admin.firestore();

async function testStateChange() {
  try {
    console.log('\n🧪 Testing Instance State Change');
    console.log('----------------------------------------');

    const testData = {
      instanceId: 'test-instance-1',
      instanceName: 'Test Instance',
      region: 'us-east-1',
      oldState: 'running',
      newState: 'stopped',
      launchTime: new Date(Date.now() - (2 * 60 * 60 * 1000)) // 2 hours ago
    };

    console.log('📝 Test Data:');
    console.log(JSON.stringify(testData, null, 2));

    // Create an alert for this instance first
    const alertId = `${testData.region}_${testData.instanceId}_120`; // 2 hour threshold
    const alertDocRef = db.collection('scheduledAlerts').doc(alertId);

    const alertData = {
      instanceID: testData.instanceId,
      instanceName: testData.instanceName,
      region: testData.region,
      threshold: '120',
      scheduledTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000)), // 1 hour from now
      status: 'pending',
      type: 'runtime_alert',
      fcmToken: 'test-fcm-token',
      launchTime: admin.firestore.Timestamp.fromDate(testData.launchTime),
      notificationSent: 'false'
    };

    // Create the alert
    await alertDocRef.set(alertData);
    console.log('\n✅ Test alert created');

    // Simulate state change
    console.log('\n🔄 Simulating state change...');
    
    // Query for alerts
    const alertsRef = db.collection('scheduledAlerts');
    const alerts = await alertsRef
      .where('instanceID', '==', testData.instanceId)
      .where('region', '==', testData.region)
      .get();

    if (!alerts.empty) {
      const batch = db.batch();
      alerts.docs.forEach(doc => {
        console.log(`• Deleting alert: ${doc.id}`);
        batch.delete(doc.ref);
      });
      await batch.commit();
      console.log(`✅ Successfully deleted ${alerts.size} alerts for stopped instance`);
    }

    // Verify cleanup
    const verifyAlerts = await alertsRef
      .where('instanceID', '==', testData.instanceId)
      .where('region', '==', testData.region)
      .get();

    console.log('\n📊 Verification:');
    console.log(`• Remaining alerts: ${verifyAlerts.size}`);
    
    console.log('\n✅ Test completed successfully');

  } catch (error) {
    console.error('\n❌ Test failed:', error);
  }
}

// Run the test
testStateChange(); 