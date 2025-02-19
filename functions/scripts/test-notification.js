const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin with service account
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Get Firestore instance
const db = admin.firestore();

// Test data with the provided FCM token
const fcmToken = 'cTvpRCcXzUsgl7tzrOQVJi:APA91bETLDPuudp5EYGRacODh7096Ygzd0Lar5P5V9PF5RM1VyLRlh_L_2CyPX1MV2T7W19BA8jhs41yzU4P-3JG6JnOIyK7B2iVDppaJQKqH-QzizNeI7s';

async function testCustomNotification() {
  try {
    console.log('\n🚀 Test 1: Sending Custom Notification');
    console.log('----------------------------------------');

    const testData = {
      token: fcmToken,
      title: '🎯 Custom Test Alert',
      body: 'Hello! This is a custom test notification with emojis 🌟✨',
      data: {
        type: 'custom_test',
        timestamp: new Date().toISOString(),
        priority: 'high'
      }
    };

    console.log('📝 Test data:');
    console.log(`  • Title: ${testData.title}`);
    console.log(`  • Body: ${testData.body}`);
    console.log(`  • Type: ${testData.data.type}`);
    console.log('----------------------------------------\n');

    const message = {
      token: testData.token,
      notification: {
        title: testData.title,
        body: testData.body
      },
      data: testData.data,
      android: {
        priority: 'high',
        notification: {
          channelId: 'default'
        }
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: testData.title,
              body: testData.body
            },
            sound: 'default',
            badge: 1
          }
        },
        headers: {
          'apns-priority': '10',
          'apns-topic': 'tech.md.Instancify'
        }
      }
    };

    const response = await admin.messaging().send(message);
    console.log('✅ Custom notification sent successfully:', response);
  } catch (error) {
    console.error('\n❌ Error sending custom notification:', error);
    throw error;
  }
}

async function testRuntimeAlert() {
  try {
    console.log('\n🚀 Test 2: Setting up Runtime Alert');
    console.log('----------------------------------------');

    // Create test instance data
    const testInstance = {
      instanceId: 'test-instance-123',
      instanceName: 'Test Instance',
      region: 'us-east-1',
      launchTime: new Date(Date.now() - 58 * 60 * 1000), // 58 minutes ago
      threshold: 60 // Alert after 60 minutes
    };

    console.log('📝 Runtime Alert Data:');
    console.log(`  • Instance: ${testInstance.instanceName} (${testInstance.instanceId})`);
    console.log(`  • Region: ${testInstance.region}`);
    console.log(`  • Launch Time: ${testInstance.launchTime.toISOString()}`);
    console.log(`  • Threshold: ${testInstance.threshold} minutes`);

    // Calculate scheduled time
    const scheduledTime = new Date(testInstance.launchTime.getTime() + testInstance.threshold * 60 * 1000);
    console.log(`  • Alert Time: ${scheduledTime.toISOString()}`);
    console.log(`  • Will trigger in: ${Math.round((scheduledTime - Date.now())/1000)} seconds`);

    // Create alert document
    const alertId = `${testInstance.region}_${testInstance.instanceId}_${testInstance.threshold}`;
    const alertData = {
      instanceID: testInstance.instanceId,
      instanceName: testInstance.instanceName,
      region: testInstance.region,
      launchTime: admin.firestore.Timestamp.fromDate(testInstance.launchTime),
      scheduledTime: admin.firestore.Timestamp.fromDate(scheduledTime),
      threshold: testInstance.threshold,
      type: 'runtime_alert',
      fcmToken: fcmToken,
      notificationSent: false,
      deleted: false,
      createdAt: admin.firestore.Timestamp.now()
    };

    await db.collection('scheduledAlerts').doc(alertId).set(alertData);
    console.log('\n✅ Runtime alert scheduled successfully');
    console.log('  • Alert ID:', alertId);
    console.log('----------------------------------------');
  } catch (error) {
    console.error('\n❌ Error setting up runtime alert:', error);
    throw error;
  }
}

async function runTests() {
  try {
    // Test 1: Custom Notification
    await testCustomNotification();

    // Test 2: Runtime Alert
    await testRuntimeAlert();

    console.log('\n✅ All tests completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Tests failed:', error);
    process.exit(1);
  }
}

runTests(); 