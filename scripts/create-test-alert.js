const admin = require('firebase-admin');
const serviceAccount = require('../service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Create a test alert that matches the Cloud Function query
const testAlert = {
  instanceID: 'i-test123',
  instanceName: 'Test Instance',
  region: 'us-east-1',
  scheduledTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 5 * 60 * 1000)), // 5 minutes ago
  status: 'pending',
  notificationSent: false,
  deleted: false,
  type: 'runtime_alert',
  fcmToken: 'test-token',
  threshold: 60, // 60 minutes runtime threshold
  createdAt: admin.firestore.Timestamp.fromDate(new Date()),
  launchTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 65 * 60 * 1000)) // Instance running for 65 minutes
};

// Also create a matching instance document
const instanceDoc = {
  id: 'i-test123',
  name: 'Test Instance',
  region: 'us-east-1',
  state: 'running',
  launchTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 65 * 60 * 1000))
};

// Create both documents in a batch
const batch = db.batch();
batch.set(db.collection('scheduledAlerts').doc('test-alert-1'), testAlert);
batch.set(db.collection('instances').doc('us-east-1_i-test123'), instanceDoc);

batch.commit()
  .then(() => {
    console.log('✅ Test alert and instance created successfully');
    console.log('Alert details:', testAlert);
    console.log('Instance details:', instanceDoc);
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error creating test documents:', error);
    process.exit(1);
  }); 