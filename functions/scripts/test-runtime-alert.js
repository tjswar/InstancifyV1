const admin = require('firebase-admin');

// Initialize Firebase Admin for emulator
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FUNCTIONS_EMULATOR = 'true';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
process.env.GCLOUD_PROJECT = 'demo-instancify';

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'demo-instancify'
});

const db = admin.firestore();

async function testRuntimeAlert() {
  try {
    console.log('\n🧪 Testing Runtime Alert');
    console.log('----------------------------------------');

    // Current time minus 1 hour for launch time
    const launchTime = new Date(Date.now() - (60 * 60 * 1000));
    
    const testData = {
      instanceId: 'test-instance-1',
      instanceName: 'Test Instance',
      region: 'us-east-1',
      hours: 2,
      minutes: 30,
      fcmToken: 'test-fcm-token',
      launchTime: launchTime.getTime()
    };

    console.log('📝 Test Data:');
    console.log(JSON.stringify(testData, null, 2));

    // Calculate threshold and scheduled time
    const threshold = (testData.hours * 60) + testData.minutes;
    const scheduledTime = new Date(launchTime.getTime() + threshold * 60 * 1000);

    // Create alert document
    const alertId = `${testData.region}_${testData.instanceId}_${threshold}`;
    const alertDocRef = db.collection('scheduledAlerts').doc(alertId);

    const alertData = {
      instanceID: testData.instanceId,
      instanceName: testData.instanceName,
      region: testData.region,
      threshold: threshold.toString(),
      scheduledTime: admin.firestore.Timestamp.fromDate(scheduledTime),
      status: "pending",
      type: "runtime_alert",
      fcmToken: testData.fcmToken,
      launchTime: admin.firestore.Timestamp.fromDate(launchTime),
      notificationSent: false,
      instanceState: "running",
      deleted: false
    };

    await alertDocRef.set(alertData);
    console.log('\n✅ Alert created successfully');
    console.log(`• Alert ID: ${alertId}`);
    console.log(`• Launch Time: ${launchTime}`);
    console.log(`• Scheduled Time: ${scheduledTime}`);

    // Wait for 5 seconds to let the alert be processed
    console.log('\n⏳ Waiting for alert processing...');
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Check alert status
    const updatedAlert = await alertDocRef.get();
    console.log('\n📊 Alert Status:');
    console.log(JSON.stringify(updatedAlert.data(), null, 2));

    console.log('\n✅ Test completed - Alert is ready for testing instance stop');

  } catch (error) {
    console.error('\n❌ Test failed:', error);
    throw error;
  }
}

// Run the test
testRuntimeAlert(); 