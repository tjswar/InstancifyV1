import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { db } from './config';
import { sendNotification } from './notifications';

export const checkScheduledAlerts = onSchedule("*/5 * * * *", async (event) => {
  try {
    logger.info("\n🔄 Starting Scheduled Alerts Check");
    logger.info("----------------------------\n");
    const currentTime = new Date();
    logger.info(`Current Time: ${currentTime.toISOString()}`);

    // First, get all pending alerts
    const pendingAlertsQuery = db.collection("scheduledAlerts")
      .where("deleted", "==", false)
      .where("status", "==", "pending")
      .where("notificationSent", "==", false)
      .where("scheduledTime", "<=", admin.firestore.Timestamp.fromDate(currentTime));

    const pendingAlerts = await pendingAlertsQuery.get();
    
    if (pendingAlerts.empty) {
      logger.info(`No pending alerts found for current time: ${currentTime.toISOString()}`);
      return;
    }

    logger.info(`Found ${pendingAlerts.size} pending alerts to process`);

    const batch = db.batch();
    const promises: Promise<any>[] = [];

    // Group alerts by region and instance for efficient instance state checking
    const alertsByRegion: { [key: string]: { [key: string]: admin.firestore.QueryDocumentSnapshot[] } } = {};
    
    pendingAlerts.docs.forEach(doc => {
      const data = doc.data();
      const region = data.region;
      const instanceId = data.instanceID;
      
      if (!alertsByRegion[region]) {
        alertsByRegion[region] = {};
      }
      if (!alertsByRegion[region][instanceId]) {
        alertsByRegion[region][instanceId] = [];
      }
      alertsByRegion[region][instanceId].push(doc);
    });

    // Check instance states and process alerts
    for (const region of Object.keys(alertsByRegion)) {
      const instanceIds = Object.keys(alertsByRegion[region]);
      
      // Get instance states from instances collection
      const instancesQuery = db.collection("instances")
        .where("region", "==", region)
        .where("id", "in", instanceIds);
      
      const instancesSnapshot = await instancesQuery.get();
      const runningInstances = new Set(
        instancesSnapshot.docs
          .filter(doc => doc.data().state === "running")
          .map(doc => doc.data().id)
      );

      // Process alerts for each instance
      for (const instanceId of instanceIds) {
        const alerts = alertsByRegion[region][instanceId];
        
        if (!runningInstances.has(instanceId)) {
          // Only cancel alerts if instance is explicitly stopped
          const instanceDoc = instancesSnapshot.docs.find(doc => doc.data().id === instanceId);
          if (instanceDoc && instanceDoc.data().state === "stopped") {
            alerts.forEach(doc => {
              // Add to notification history
              const historyRef = db.collection("notificationHistory").doc();
              batch.set(historyRef, {
                ...doc.data(),
                status: "cancelled",
                error: "Instance is stopped",
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
                timestamp: admin.firestore.FieldValue.serverTimestamp()
              });
              // Delete the alert document
              batch.delete(doc.ref);
            });
          }
          continue;
        }

        // Process alerts for running instances
        for (const doc of alerts) {
          const alert = doc.data();
          const scheduledTime = alert.scheduledTime.toDate();
          
          if (currentTime >= scheduledTime) {
            logger.info(`🔔 Processing alert for instance ${alert.instanceName} (${alert.instanceID})`);
            logger.info(`Scheduled Time: ${scheduledTime.toISOString()}`);
            logger.info(`Current Time: ${currentTime.toISOString()}`);
            logger.info(`Alert Data:`, alert);
            
            const notificationData = {
              title: "Instance Runtime Alert",
              body: `Your instance ${alert.instanceName} has been running for ${alert.threshold} minutes`,
              data: {
                instanceId: alert.instanceID,
                instanceName: alert.instanceName,
                runtime: alert.threshold.toString(),
                region: alert.region,
                type: "runtime_alert"
              }
            };

            promises.push(
              sendNotification(alert.fcmToken, notificationData)
                .then(() => {
                  // Add to notification history
                  const historyRef = db.collection("notificationHistory").doc();
                  batch.set(historyRef, {
                    ...alert,
                    status: "completed",
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                    timestamp: admin.firestore.FieldValue.serverTimestamp()
                  });
                  // Delete the alert document
                  batch.delete(doc.ref);
                })
                .catch((error) => {
                  logger.error(`Error sending notification: ${error.message}`);
                  // Add failed notification to history
                  const historyRef = db.collection("notificationHistory").doc();
                  batch.set(historyRef, {
                    ...alert,
                    status: "failed",
                    error: error.message,
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                    timestamp: admin.firestore.FieldValue.serverTimestamp()
                  });
                  // Delete the alert document even if notification fails
                  batch.delete(doc.ref);
                })
            );
          }
        }
      }
    }

    await Promise.all(promises);
    await batch.commit();
    logger.info("✅ Alert check completed successfully");

  } catch (error: any) {
    logger.error("\n❌ Error in alert check:", error);
    throw error;
  }
});

// Send push notification
export const sendNotificationFunction = onCall(async (request) => {
  try {
    logger.info("\n📱 Processing notification request");
    logger.info("----------------------------------------");
    logger.info("📊 Notification Data:", request.data);

    // The data comes wrapped in a data object from the client
    const notificationData = request.data.data || request.data;
    const { token, title, body, data } = notificationData;

    if (!token || !title || !body) {
      logger.error("❌ Missing required fields:", { token, title, body });
      throw new Error("Missing required notification data");
    }

    const result = await sendNotification(token, {
      title,
      body,
      data: data || {}
    });

    logger.info("✅ Message sent successfully:", result);
    return { success: true, messageId: result };
  } catch (error: unknown) {
    if (error instanceof Error) {
      logger.error("❌ Error sending notification:", error);
      throw new Error(`Failed to send notification: ${error.message}`);
    }
    throw error;
  }
}); 