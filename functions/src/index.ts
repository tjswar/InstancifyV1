/**
 * Import function triggers from their respective submodules:
 */

import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onCall, CallableRequest, HttpsError, onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {getFirestore} from "firebase-admin/firestore";

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

// Get Firestore instance
const db = getFirestore();

interface RuntimeAlertRequest {
  instanceId: string;
  instanceName: string;
  region: string;
  hours: number;
  minutes: number;
  fcmToken: string;
  launchTime: number;
}

// Schedule a runtime alert
export const scheduleRuntimeAlert = onCall(
  async (request: CallableRequest<RuntimeAlertRequest>) => {
    try {
      const {instanceId, instanceName, region, hours, minutes, fcmToken, launchTime} = request.data;

      // Log the request data
      logger.info("\n📝 Scheduling Runtime Alert:");
      logger.info(`• Instance: ${instanceName} (${instanceId})`);
      logger.info(`• Region: ${region}`);
      logger.info(`• Duration: ${hours}h ${minutes}m`);
      logger.info(`• Launch Time: ${new Date(launchTime).toISOString()}`);

      // Validate required fields
      if (!instanceId || !instanceName || !region || !fcmToken || !launchTime) {
        throw new HttpsError(
          "invalid-argument",
          "Missing required fields"
        );
      }

      const launchDate = new Date(launchTime);
      
      // Calculate threshold in minutes
      const threshold = (hours * 60) + minutes;
      
      // Calculate scheduled time from launch time
      const scheduledTime = new Date(launchDate.getTime() + (threshold * 60 * 1000));
      
      logger.info(`• Threshold: ${threshold} minutes`);
      logger.info(`• Scheduled Time: ${scheduledTime.toISOString()}`);

      // Create new alert
      const alertId = `${region}_${instanceId}_${threshold}`;
      const alertDocRef = admin.firestore().collection("scheduledAlerts").doc(alertId);
      
      // Store all data as strings
      const alertData = {
        instanceID: instanceId.toString(),
        instanceName: instanceName.toString(),
        region: region.toString(),
        threshold: threshold.toString(),
        scheduledTime: admin.firestore.Timestamp.fromDate(scheduledTime),
        status: "pending",
        type: "runtime_alert",
        fcmToken: fcmToken.toString(),
        launchTime: admin.firestore.Timestamp.fromDate(launchDate),
        notificationSent: false,
        deleted: false,
        hours: hours.toString(),
        minutes: minutes.toString(),
        createdAt: admin.firestore.Timestamp.now()
      };

      await alertDocRef.set(alertData);
      logger.info(`✅ Alert scheduled successfully`);
      logger.info(`• Alert ID: ${alertId}`);
      logger.info(`• Will trigger at: ${scheduledTime.toISOString()}`);
      
      return { success: true };
    } catch (error) {
      logger.error("❌ Error scheduling alert:", error);
      throw error instanceof HttpsError ? error : new HttpsError("internal", "Failed to schedule runtime alert");
    }
  }
);

// Add interface for alert data
interface AlertData {
  instanceID: string;
  instanceName: string;
  region: string;
  threshold: string;
  scheduledTime: FirebaseFirestore.Timestamp;
  status: string;
  type: string;
  fcmToken: string;
  launchTime: FirebaseFirestore.Timestamp;
  notificationSent: boolean;
  deleted: boolean;
  hours: string;
  minutes: string;
  createdAt: FirebaseFirestore.Timestamp;
  instanceState?: string;
}

interface AlertDoc {
  doc: FirebaseFirestore.QueryDocumentSnapshot;
  alert: AlertData;
}

// Check scheduled alerts every minute
export const checkScheduledAlerts = onSchedule("*/1 * * * *", async (event) => {
  try {
    const currentTime = admin.firestore.Timestamp.now();
    logger.info(`\n⏰ Checking alerts at ${currentTime.toDate().toISOString()}`);

    // Get all pending alerts that are not deleted and where instance is running
    const alertsRef = db.collection("scheduledAlerts");
    const alerts = await alertsRef
      .where("status", "==", "pending")
      .where("notificationSent", "==", false)
      .where("instanceState", "==", "running")  // Only get alerts for running instances
      .orderBy("scheduledTime", "asc")  // Order by scheduled time to process oldest first
      .get();

    logger.info(`\n📊 Found ${alerts.size} pending alerts for running instances`);

    // Group alerts by instance to prevent duplicates
    const alertsByInstance = new Map<string, AlertDoc[]>();
    alerts.docs.forEach(doc => {
      const alert = doc.data() as AlertData;
      const instanceKey = `${alert.instanceID}_${alert.region}`;
      logger.info(`Processing alert for instance ${instanceKey}`);
      logger.info(`• Instance State: ${alert.instanceState}`);
      logger.info(`• Region: ${alert.region}`);
      
      if (!alertsByInstance.has(instanceKey)) {
        alertsByInstance.set(instanceKey, []);
      }
      alertsByInstance.get(instanceKey)?.push({ doc, alert });
    });

    // Process alerts by instance
    for (const [instanceKey, instanceAlerts] of alertsByInstance) {
      logger.info(`\n🔍 Processing alerts for instance: ${instanceKey}`);
      
      // Sort alerts by threshold
      instanceAlerts.sort((a: AlertDoc, b: AlertDoc) => 
        parseInt(a.alert.threshold) - parseInt(b.alert.threshold)
      );
      
      // Get the earliest scheduled alert that's due
      const dueAlert = instanceAlerts.find(({ alert }) => 
        currentTime.toMillis() >= alert.scheduledTime.toMillis()
      );

      if (!dueAlert) {
        logger.info(`⏳ No alerts due yet for this instance`);
        continue;
      }

      const { doc, alert } = dueAlert;
      logger.info(`\n🔔 Processing alert for ${alert.instanceName}:`);
      logger.info(`• Instance ID: ${alert.instanceID}`);
      logger.info(`• Region: ${alert.region}`);
      logger.info(`• Threshold: ${alert.threshold} minutes`);
      logger.info(`• Instance State: ${alert.instanceState}`);

      // Calculate runtime in minutes
      const runtimeMinutes = Math.floor(
        (currentTime.toMillis() - alert.launchTime.toMillis()) / 60000
      );
      
      try {
        // Double check instance state before sending notification
        if (alert.instanceState !== "running") {
          logger.info(`🛑 Instance is no longer running (state: ${alert.instanceState}), cleaning up alerts`);
          // Clean up all alerts for this instance
          const batch = db.batch();
          instanceAlerts.forEach(({ doc }) => batch.delete(doc.ref));
          await batch.commit();
          continue;
        }
        
        logger.info(`• Current Runtime: ${Math.floor(runtimeMinutes / 60)}h ${runtimeMinutes % 60}m`);

        // Send notification
        const message = {
          token: alert.fcmToken,
          notification: {
            title: "⏰ Runtime Alert",
            body: `${alert.instanceName} has been running for ${Math.floor(runtimeMinutes / 60)}h ${runtimeMinutes % 60}m`
          },
          data: {
            type: "runtime_alert",
            instanceId: alert.instanceID.toString(),
            instanceName: alert.instanceName.toString(),
            region: alert.region.toString(),
            runtime: runtimeMinutes.toString(),
            threshold: alert.threshold.toString(),
            launchTime: alert.launchTime.toDate().toISOString(),
            scheduledTime: alert.scheduledTime.toDate().toISOString(),
            currentTime: currentTime.toDate().toISOString()
          }
        };

        await admin.messaging().send(message);
        logger.info(`✅ Notification sent for ${alert.instanceName}`);

        // Add to notification history
        const historyRef = db.collection("notificationHistory").doc();
        await historyRef.set({
          type: "runtime_alert",
          title: message.notification.title,
          body: message.notification.body,
          instanceId: alert.instanceID,
          instanceName: alert.instanceName,
          region: alert.region,
          runtime: runtimeMinutes,
          threshold: parseInt(alert.threshold),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          time: currentTime.toDate().toISOString(),
          status: "completed",
          data: message.data,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          formattedTime: currentTime.toDate().toLocaleTimeString('en-US', { 
            hour: 'numeric',
            minute: 'numeric',
            hour12: true 
          })
        });

        // Delete the processed alert and any alerts with lower thresholds
        const batch = db.batch();
        instanceAlerts
          .filter(({ alert: a }) => parseInt(a.threshold) <= parseInt(alert.threshold))
          .forEach(({ doc }) => batch.delete(doc.ref));
        await batch.commit();
        
        logger.info("✅ Alert processed and cleaned up");

      } catch (error) {
        logger.error(`❌ Error processing alert:`, error);
        // Add failed notification to history
        const historyRef = db.collection("notificationHistory").doc();
        await historyRef.set({
          type: "runtime_alert",
          title: "⏰ Runtime Alert",
          body: `Failed to send alert for ${alert.instanceName}`,
          instanceId: alert.instanceID,
          instanceName: alert.instanceName,
          region: alert.region,
          runtime: runtimeMinutes,
          threshold: parseInt(alert.threshold),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          time: currentTime.toDate().toISOString(),
          status: "error",
          error: error instanceof Error ? error.message : "Unknown error",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          formattedTime: currentTime.toDate().toLocaleTimeString('en-US', { 
            hour: 'numeric',
            minute: 'numeric',
            hour12: true 
          })
        });

        // Mark alert as error but don't delete it
        await doc.ref.update({
          error: error instanceof Error ? error.message : "Unknown error",
          status: "error",
          lastErrorAt: currentTime
        });
      }
    }
  } catch (error) {
    logger.error("❌ Error checking alerts:", error);
  }
});

// Delete alerts for an instance
export const deleteInstanceAlerts = onCall(
  async (request: CallableRequest<{
    instanceId: string;
    region: string;
  }>) => {
    try {
      const {instanceId, region} = request.data;
      logger.info("\n🗑️ Deleting alerts for instance");
      logger.info(`• Instance ID: ${instanceId}`);
      logger.info(`• Region: ${region}`);

      if (!instanceId || !region) {
        logger.error("❌ Missing required fields:", {instanceId, region});
        throw new HttpsError("invalid-argument", "Missing required fields");
      }

      // Get all alerts for this instance
      const alertsRef = db.collection("scheduledAlerts");
      const alerts = await alertsRef
        .where("instanceID", "==", instanceId)
        .where("region", "==", region)
        .get();

      if (!alerts.empty) {
        logger.info(`Found ${alerts.size} alerts to delete`);
        
        // Get instance name from first alert for notification
        const instanceName = alerts.docs[0].data().instanceName;
        const fcmToken = alerts.docs[0].data().fcmToken;

        // Delete all alerts
        const batch = db.batch();
        alerts.docs.forEach(doc => {
          logger.info(`🗑️ Deleting alert: ${doc.id}`);
          batch.delete(doc.ref);
        });
        await batch.commit();
        logger.info(`✅ Successfully deleted ${alerts.size} alerts`);
        
        // Add cleanup notification to history
        const historyRef = db.collection("notificationHistory").doc();
        const notificationData = {
          type: "alert_cleanup",
          title: "Alerts Cancelled",
          body: `All runtime alerts for ${instanceName} have been cancelled`,
          instanceId: instanceId,
          instanceName: instanceName,
          region: region,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          time: new Date().toISOString(),
          status: "completed",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          formattedTime: new Date().toLocaleTimeString('en-US', { 
            hour: 'numeric',
            minute: 'numeric',
            hour12: true 
          })
        };
        
        await historyRef.set(notificationData);
        logger.info("✅ Added cleanup notification to history");
        
        // Send notification about cancelled alerts
        try {
          // Skip FCM in emulator
          if (process.env.FUNCTIONS_EMULATOR !== "true") {
            const message = {
              token: fcmToken,
              notification: {
                title: "Alerts Cancelled",
                body: `All runtime alerts for ${instanceName} have been cancelled`
              },
              data: {
                type: "alert_cleanup",
                instanceId: instanceId,
                instanceName: instanceName,
                region: region
              }
            };
            await admin.messaging().send(message);
            logger.info("✅ Cleanup notification sent");
          } else {
            logger.info("ℹ️ Skipping FCM notification in emulator");
          }
        } catch (error) {
          logger.error("❌ Error sending cleanup notification:", error);
        }

        return {
          success: true,
          alertsDeleted: alerts.size
        };
      } else {
        logger.info("ℹ️ No alerts found to delete");
        return {
          success: true,
          alertsDeleted: 0
        };
      }
    } catch (error) {
      logger.error("❌ Error deleting alerts:", error);
      throw error instanceof HttpsError ? error : new HttpsError(
        "internal",
        "Failed to delete alerts"
      );
    }
  }
);

// Modify handleInstanceStateChange to use the new function
export const handleInstanceStateChange = onCall(
  async (request: CallableRequest<{
    instanceId: string;
    region: string;
    newState: string;
  }>) => {
    try {
      const {instanceId, region, newState} = request.data;
      logger.info("\n🔄 Processing state change request:");
      logger.info(`• Instance ID: ${instanceId}`);
      logger.info(`• Region: ${region}`);
      logger.info(`• New State: ${newState}`);
      logger.info(`• Raw request data: ${JSON.stringify(request.data)}`);

      if (!instanceId || !region || !newState) {
        logger.error("❌ Missing required fields:", {instanceId, region, newState});
        throw new HttpsError("invalid-argument", "Missing required fields");
      }

      // If instance is stopped/stopping/terminated, delete alerts
      if (newState === "stopped" || newState === "stopping" || newState === "terminated") {
        logger.info(`\n🗑️ Instance is ${newState}, deleting alerts`);
        
        try {
          // Call the new deleteInstanceAlerts function directly
          const deleteResult = await db.collection("scheduledAlerts")
            .where("instanceID", "==", instanceId)
            .where("region", "==", region)
            .get();

          if (!deleteResult.empty) {
            const batch = db.batch();
            deleteResult.docs.forEach(doc => {
              logger.info(`🗑️ Deleting alert: ${doc.id}`);
              batch.delete(doc.ref);
            });
            await batch.commit();
            logger.info(`✅ Successfully deleted ${deleteResult.size} alerts`);

            // Get instance name from first alert for notification
            const instanceName = deleteResult.docs[0].data().instanceName;
            const fcmToken = deleteResult.docs[0].data().fcmToken;

            // Add cleanup notification to history
            const historyRef = db.collection("notificationHistory").doc();
            const notificationData = {
              type: "alert_cleanup",
              title: "Alerts Cancelled",
              body: `All runtime alerts for ${instanceName} have been cancelled because the instance was ${newState}`,
              instanceId: instanceId,
              instanceName: instanceName,
              region: region,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              time: new Date().toISOString(),
              status: "completed",
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              formattedTime: new Date().toLocaleTimeString('en-US', { 
                hour: 'numeric',
                minute: 'numeric',
                hour12: true 
              })
            };
            
            await historyRef.set(notificationData);
            logger.info("✅ Added cleanup notification to history");

            // Send notification about cancelled alerts
            try {
              // Skip FCM in emulator
              if (process.env.FUNCTIONS_EMULATOR !== "true") {
                const message = {
                  token: fcmToken,
                  notification: {
                    title: "Alerts Cancelled",
                    body: `All runtime alerts for ${instanceName} have been cancelled because the instance was ${newState}`
                  },
                  data: {
                    type: "alert_cleanup",
                    instanceId: instanceId,
                    instanceName: instanceName,
                    region: region,
                    state: newState
                  }
                };
                await admin.messaging().send(message);
                logger.info("✅ Cleanup notification sent");
              } else {
                logger.info("ℹ️ Skipping FCM notification in emulator");
              }
            } catch (error) {
              logger.error("❌ Error sending cleanup notification:", error);
            }
          } else {
            logger.info("ℹ️ No alerts found to delete");
          }
          
          logger.info("✅ Alert deletion completed");
        } catch (error) {
          logger.error("❌ Error deleting alerts:", error);
          throw new HttpsError("internal", "Failed to delete alerts");
        }
      } else {
        // Update instance state in all alerts
        try {
          const alertsRef = db.collection("scheduledAlerts");
          const alerts = await alertsRef
            .where("instanceID", "==", instanceId)
            .where("region", "==", region)
            .get();

          if (!alerts.empty) {
            const batch = db.batch();
            alerts.docs.forEach(doc => {
              batch.update(doc.ref, { instanceState: newState });
            });
            await batch.commit();
            logger.info(`✅ Updated state to "${newState}" for ${alerts.size} alerts`);
          }
        } catch (error) {
          logger.error("❌ Error updating alert states:", error);
          throw new HttpsError("internal", "Failed to update alert states");
        }
      }

      return {
        success: true,
        instanceId,
        newState,
        alertsCleanedUp: true
      };
      
    } catch (error) {
      logger.error("❌ Error in handleInstanceStateChange:", error);
      throw error instanceof HttpsError ? error : new HttpsError(
        "internal", 
        "Failed to process state change"
      );
    }
  }
);

// Send push notification
export const sendNotificationFunction = onRequest({
  region: 'us-central1',
  maxInstances: 10,
  cors: true
}, async (req, res) => {
  try {
    logger.info("\n📱 Processing notification request");
    logger.info("----------------------------------------");
    logger.info("📊 Notification Data:", req.body);

    // The data comes from the request body
    const notificationData = req.body.data || req.body;
    const { token, title, body, data } = notificationData;

    if (!token || !title || !body) {
      logger.error("❌ Missing required fields:", { token, title, body });
      res.status(400).json({ data: { error: "Missing required notification data" } });
      return;
    }

    // Construct the message
    const message: admin.messaging.Message = {
      token,
      notification: {
        title,
        body
      },
      data: data || {},
      android: {
        priority: "high",
        notification: {
          channelId: "default"
        }
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title,
              body
            },
            sound: "default",
            badge: 1
          }
        },
        headers: {
          "apns-priority": "10",
          "apns-topic": "tech.md.Instancify"
        }
      }
    };

    try {
      // Save to notification history
      await admin.firestore().collection("notificationHistory").add({
        type: data?.type || "custom",
        title,
        body,
        timestamp: admin.firestore.Timestamp.now(),
        ...data
      });

      // Send the notification
      const response = await admin.messaging().send(message);
      logger.info("✅ Message sent successfully:", response);
      res.json({ 
        data: {
          success: true,
          messageId: response,
          notification: {
            title,
            body,
            data
          }
        }
      });
    } catch (error: any) {
      logger.error("❌ Error sending notification:", error);
      res.status(500).json({ data: { error: `Failed to send notification: ${error.message}` } });
    }
  } catch (error: unknown) {
    if (error instanceof Error) {
      logger.error("❌ Error in sendNotificationFunction:", error);
      res.status(500).json({ data: { error: `Failed to process notification: ${error.message}` } });
    } else {
      res.status(500).json({ data: { error: "An unknown error occurred" } });
    }
  }
});

// Add cleanup function to delete old data
export const cleanupOldData = onSchedule("0 0 * * *", async (event) => {
  try {
    logger.info("\n🧹 Starting daily cleanup");
    const db = getFirestore();
    const batch = db.batch();
    const batchSize = 450; // Firestore batch limit is 500, using 450 to be safe
    let totalDeleted = 0;
    
    // Calculate cutoff date (48 hours ago)
    const cutoffDate = new Date();
    cutoffDate.setHours(cutoffDate.getHours() - 48);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);
    
    // 1. Clean up notification history
    logger.info("\n🗑️ Cleaning up notification history");
    const historyDocs = await db.collection("notificationHistory")
      .where("timestamp", "<=", cutoffTimestamp)
      .limit(batchSize)
      .get();
    
    historyDocs.forEach(doc => {
      batch.delete(doc.ref);
      totalDeleted++;
    });
    
    // 2. Clean up failed notifications
    logger.info("🗑️ Cleaning up failed notifications");
    const failedDocs = await db.collection("failedNotifications")
      .where("timestamp", "<=", cutoffTimestamp)
      .limit(batchSize - totalDeleted)
      .get();
    
    failedDocs.forEach(doc => {
      batch.delete(doc.ref);
      totalDeleted++;
    });
    
    // 3. Clean up completed/failed alerts
    logger.info("🗑️ Cleaning up old alerts");
    const alertDocs = await db.collection("scheduledAlerts")
      .where("status", "in", ["completed", "failed"])
      .where("createdAt", "<=", cutoffTimestamp)
      .limit(batchSize - totalDeleted)
      .get();
    
    alertDocs.forEach(doc => {
      batch.delete(doc.ref);
      totalDeleted++;
    });
    
    // Commit the batch
    if (totalDeleted > 0) {
      await batch.commit();
      logger.info(`✅ Cleanup completed. Deleted ${totalDeleted} documents`);
    } else {
      logger.info("✅ No documents to clean up");
    }
    
  } catch (error) {
    logger.error("❌ Error during cleanup:", error);
  }
});
