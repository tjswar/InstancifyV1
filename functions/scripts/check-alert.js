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

async function checkAlert() {
  try {
    console.log('\n🔍 Checking alert document...');
    const doc = await db.collection('scheduledAlerts').doc('test-alert-1').get();
    
    if (!doc.exists) {
      console.log('❌ Alert document not found');
      process.exit(1);
    }

    console.log('\n📄 Alert document state:');
    console.log(JSON.stringify(doc.data(), null, 2));
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
}

checkAlert(); 