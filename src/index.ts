import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions';
import { db } from './config';
import { sendNotification } from './notifications';

export const checkScheduledAlerts = onSchedule("*/5 * * * *", async (event) => {
  try {
    logger.info("\n🔄 Starting Scheduled Alerts Check");
    logger.info("----------------------------\n");
    const currentTime = new Date();
    logger.info(`Current Time: ${currentTime.toISOString()}`);

    // First, get all active alerts
    const activeAlertsQuery = db.collection("scheduledAlerts")
      .where("deleted", "==", false)
      .where("status", "==", "active")
      .where("notificationSent", "==", false);

    const activeAlerts = await activeAlertsQuery.get();
    
    if (activeAlerts.empty) {
      logger.info("No pending alerts found");
      return;
    }

    const batch = db.batch();
    const promises: Promise<any>[] = [];

    for (const doc of activeAlerts.docs) {
      const alert = doc.data();
      
      // Check if the instance is still running and has a valid device token
      if (alert.instanceState !== "running" || !alert.deviceToken) {
        batch.update(doc.ref, {
          status: "cancelled",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        continue;
      }

      // Calculate time threshold
      const threshold = alert.threshold || 0;
      if (threshold <= 0) continue;

      const scheduledTime = new Date(alert.scheduledTime);
      const runtime = Math.floor((currentTime.getTime() - scheduledTime.getTime()) / (60 * 1000));

      if (runtime >= threshold) {
        logger.info(`🔔 Alert triggered for instance ${alert.instanceName} (Runtime: ${runtime} minutes, Threshold: ${threshold} minutes)`);
        
        const notificationData = {
          title: "Instance Runtime Alert",
          body: `Your instance ${alert.instanceName} has been running for ${runtime} minutes`,
          data: {
            instanceId: alert.instanceId,
            instanceName: alert.instanceName,
            runtime: runtime.toString(),
            threshold: threshold.toString(),
            alertId: doc.id
          }
        };

        promises.push(
          sendNotification(alert.deviceToken, notificationData)
            .then(() => {
              batch.update(doc.ref, {
                notificationSent: true,
                status: "completed",
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
              });
            })
            .catch((error) => {
              logger.error(`Error sending notification: ${error.message}`);
              batch.update(doc.ref, {
                status: "failed",
                error: error.message,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
              });
            })
        );
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