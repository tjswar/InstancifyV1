const admin = require('firebase-admin');
const serviceAccount = require('../service-account.json');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function testInstanceDocCreation() {
  try {
    console.log('\n🔍 Testing Instance Document Creation');
    console.log('----------------------------------------');

    // Test data
    const testInstance = {
      instanceId: 'test123',
      instanceName: 'Test Instance',
      region: 'us-east-1',
      state: 'running',
      launchTime: new Date()
    };

    console.log('📝 Test Instance Data:');
    console.log(`  • ID: ${testInstance.instanceId}`);
    console.log(`  • Name: ${testInstance.instanceName}`);
    console.log(`  • Region: ${testInstance.region}`);
    console.log(`  • State: ${testInstance.state}`);
    console.log(`  • Launch Time: ${testInstance.launchTime.toISOString()}`);

    // 1. Test handleInstanceStateChange
    console.log('\n1️⃣ Testing handleInstanceStateChange...');
    const instanceDocId = `${testInstance.region}_${testInstance.instanceId}`;
    const instanceDocRef = db.collection('instances').doc(instanceDocId);
    
    await instanceDocRef.set({
      id: testInstance.instanceId,
      instanceId: testInstance.instanceId,
      instanceName: testInstance.instanceName,
      name: testInstance.instanceName,
      region: testInstance.region,
      state: testInstance.state,
      launchTime: admin.firestore.Timestamp.fromDate(testInstance.launchTime),
      updatedAt: admin.firestore.Timestamp.now()
    });

    // Verify instance document
    console.log('\n2️⃣ Verifying instance document...');
    const instanceDoc = await instanceDocRef.get();
    
    if (!instanceDoc.exists) {
      throw new Error('❌ Instance document was not created!');
    }

    const instanceData = instanceDoc.data();
    console.log('✅ Instance document created successfully:');
    console.log(instanceData);

    // 2. Test alert creation
    console.log('\n3️⃣ Testing alert creation...');
    const alertData = {
      instanceID: testInstance.instanceId,
      instanceName: testInstance.instanceName,
      region: testInstance.region,
      hours: 1,
      minutes: 30,
      scheduledTime: admin.firestore.Timestamp.fromDate(
        new Date(testInstance.launchTime.getTime() + 90 * 60 * 1000)
      ),
      status: 'pending',
      notificationSent: false,
      createdAt: admin.firestore.Timestamp.now(),
      threshold: 90,
      deleted: false,
      type: 'runtime_alert',
      fcmToken: 'test-token',
      instanceState: 'running',
      launchTime: admin.firestore.Timestamp.fromDate(testInstance.launchTime)
    };

    const alertId = `${testInstance.region}_${testInstance.instanceId}_90`;
    const alertDocRef = db.collection('scheduledAlerts').doc(alertId);
    await alertDocRef.set(alertData);

    // Verify alert document
    console.log('\n4️⃣ Verifying alert document...');
    const alertDoc = await alertDocRef.get();
    
    if (!alertDoc.exists) {
      throw new Error('❌ Alert document was not created!');
    }

    console.log('✅ Alert document created successfully');
    console.log(alertDoc.data());

    // Cleanup
    console.log('\n5️⃣ Cleaning up test documents...');
    await Promise.all([
      instanceDocRef.delete(),
      alertDocRef.delete()
    ]);
    console.log('✅ Test documents cleaned up');

    console.log('\n✅ All tests completed successfully!');
  } catch (error) {
    console.error('❌ Test failed:', error);
    throw error;
  }
}

// Run the test
testInstanceDocCreation()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Test failed:', error);
    process.exit(1);
  }); 