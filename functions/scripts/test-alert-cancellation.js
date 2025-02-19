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

async function testAlertCancellation() {
  try {
    console.log('\n🧪 Testing Alert Cancellation');
    console.log('----------------------------------------');

    // Test instance details
    const testInstance = {
      instanceId: 'test-instance-1',
      instanceName: 'Test Instance',
      region: 'us-east-1',
      fcmToken: 'test-fcm-token'
    };

    // 1. First create a test alert
    console.log('\n1️⃣ Creating test alert...');
    const alertId = `${testInstance.region}_${testInstance.instanceId}_120`;
    const alertDocRef = db.collection('scheduledAlerts').doc(alertId);

    const alertData = {
      instanceID: testInstance.instanceId,
      instanceName: testInstance.instanceName,
      region: testInstance.region,
      threshold: '120',
      scheduledTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000)),
      status: 'pending',
      type: 'runtime_alert',
      fcmToken: testInstance.fcmToken,
      launchTime: admin.firestore.Timestamp.now(),
      notificationSent: false,
      instanceState: 'running',
      deleted: false
    };

    await alertDocRef.set(alertData);
    console.log('✅ Test alert created with ID:', alertId);

    // Wait a moment to ensure alert is created
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Verify alert was created
    const alertDoc = await alertDocRef.get();
    if (alertDoc.exists) {
      console.log('✅ Alert verified in database');
      console.log('Alert data:', alertDoc.data());
    } else {
      throw new Error('Alert was not created successfully');
    }

    // 2. Simulate instance state change to stopped
    console.log('\n2️⃣ Simulating instance stop...');
    
    // Import the function from the compiled code
    const { handleInstanceStateChange } = require('../lib/index.js');
    
    const stateChangeData = {
      instanceId: testInstance.instanceId,
      region: testInstance.region,
      newState: 'stopped'
    };

    console.log('Calling handleInstanceStateChange with data:', stateChangeData);

    const result = await handleInstanceStateChange.run({
      data: stateChangeData
    }, {
      auth: {
        uid: 'test-user',
        token: {}
      }
    });

    console.log('\n✅ State change processed');
    console.log('Result:', result);

    // 3. Verify cleanup
    console.log('\n3️⃣ Verifying cleanup...');
    
    // Check if alert was deleted
    const alertAfter = await alertDocRef.get();
    console.log('Alert exists after cleanup:', alertAfter.exists);

    // Check notification history
    const notifications = await db.collection('notificationHistory')
      .where('type', '==', 'alert_cleanup')
      .where('instanceId', '==', testInstance.instanceId)
      .get();

    if (!notifications.empty) {
      console.log('\n✅ Cleanup notification found:');
      console.log(notifications.docs[0].data());
    } else {
      console.log('\n❌ No cleanup notification found');
    }

    console.log('\n✅ Test completed');

  } catch (error) {
    console.error('\n❌ Test failed:', error);
    console.error('Error details:', error.stack);
  }
}

// Run the test
testAlertCancellation(); 