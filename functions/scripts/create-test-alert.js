const admin = require('firebase-admin');
const serviceAccount = require('../../service-account.json');

// Initialize Firebase Admin
try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('✅ Firebase Admin initialized successfully');
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin:', error);
  process.exit(1);
}

const db = admin.firestore();

async function createTestDocuments() {
  try {
    console.log('\n📝 Creating test documents...');
    
    const now = new Date();
    const launchTime = new Date(now.getTime() - 65 * 60 * 1000); // 65 minutes ago
    const scheduledTime = new Date(now.getTime() - 5 * 60 * 1000); // 5 minutes ago
    
    // First, create the instance document
    const instanceDoc = {
      id: 'i-test123',
      name: 'Test Instance',
      region: 'us-east-1',
      state: 'running',
      launchTime: admin.firestore.Timestamp.fromDate(launchTime)
    };

    // Create the alert document
    const testAlert = {
      instanceID: 'i-test123',
      instanceName: 'Test Instance',
      region: 'us-east-1',
      scheduledTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 60 * 1000)), // 1 minute ago
      status: 'pending',
      notificationSent: false,
      deleted: false,
      type: 'runtime_alert',
      fcmToken: 'test-token',
      threshold: 60, // 60 minutes runtime threshold
      createdAt: admin.firestore.Timestamp.now(),
      launchTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 61 * 60 * 1000)) // Instance running for 61 minutes
    };

    // Create both documents in a batch
    const batch = db.batch();
    batch.set(db.collection('scheduledAlerts').doc('test-alert-1'), testAlert);
    batch.set(db.collection('instances').doc('us-east-1_i-test123'), instanceDoc);  // Updated document ID format

    // Verify the documents
    const alertDoc = await db.collection('scheduledAlerts').doc('test-alert-1').get();
    const instanceDocVerify = await db.collection('instances').doc('us-east-1_i-test123').get();

    console.log('\n🔍 Verifying documents:');
    console.log(`Alert document exists: ${alertDoc.exists}`);
    console.log(`Instance document exists: ${instanceDocVerify.exists}`);

    if (alertDoc.exists) {
      console.log('\n📄 Retrieved Alert Document:');
      console.log(JSON.stringify(alertDoc.data(), null, 2));
    }

    if (instanceDocVerify.exists) {
      console.log('\n📄 Retrieved Instance Document:');
      console.log(JSON.stringify(instanceDocVerify.data(), null, 2));
    }

    // Wait for 10 seconds to let the Cloud Function process the alert
    console.log('\n⏳ Waiting for Cloud Function to process alert...');
    await new Promise(resolve => setTimeout(resolve, 10000));

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
}

createTestDocuments();
