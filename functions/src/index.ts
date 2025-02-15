/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onCall, CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as functions from "firebase-functions";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Initialize Firebase Admin
admin.initializeApp();

interface AlertData {
  instanceID: string;
  instanceName: string;
  region: string;
  hours: number;
  minutes: number;
  scheduledTime: admin.firestore.Timestamp;
  status: string;
  notificationSent: boolean;
  instanceState: string;
  deleted: boolean;
  launchTime: admin.firestore.Timestamp;
  fcmToken: string;
  createdAt: admin.firestore.Timestamp;
  threshold: number;
  type: string;
  regions: string[];
}

interface NotificationData {
    title: string;
    body: string;
    token: string;
    payload?: Record<string, string>;
}

interface RuntimeAlertRequest {
    instanceId: string;
    instanceName: string;
    region: string;
    hours: number;
    minutes: number;
    regions?: string[];
    fcmToken?: string;
    instanceState?: string;
}

// Schedule a runtime alert
export const scheduleRuntimeAlert = onCall(
  async (request: CallableRequest<RuntimeAlertRequest>) => {
    try {
      const {instanceId, instanceName, region, hours, minutes, regions, fcmToken, instanceState} = request.data;

      // Only create alerts for running instances
      if (instanceState !== "running") {
        logger.info(`Skipping alert creation for instance ${instanceName} - state is ${instanceState}`);
        return {
          success: false,
          error: "Alerts can only be created for running instances",
        };
      }

      // Validate required fields
      if (!fcmToken) {
        logger.error("Missing FCM token");
        return {
          success: false,
          error: "FCM token is required",
        };
      }

      // Create the new alert document with proper ID format
      const alertId = `${region}_${instanceId}_${Date.now()}`;
      const alertRef = admin.firestore().collection("scheduledAlerts").doc(alertId);

      // Calculate scheduled time and threshold
      const threshold = (hours * 60) + minutes;
      const scheduledTime = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + threshold * 60 * 1000)
      );

      const alertData = {
        instanceId: instanceId,
        instanceName: instanceName || instanceId,
        region,
        hours: hours || 0,
        minutes: minutes || 0,
        scheduledTime,
        status: "pending",
        notificationSent: false,
        createdAt: admin.firestore.Timestamp.now(),
        regions: regions || [region],
        threshold,
        deleted: false,
        type: "instance_alert",
        fcmToken,
        instanceState: "running",
        launchTime: admin.firestore.Timestamp.now(),
      };

      await alertRef.set(alertData);

      return {
        success: true,
        alertId: alertRef.id,
      };
    } catch (error) {
      logger.error("Error scheduling runtime alert:", error);
      throw new HttpsError("internal", "Failed to schedule runtime alert");
    }
  }
);

// Check scheduled alerts every minute
export const checkScheduledAlerts = onSchedule({
  schedule: "* * * * *",
  timeoutSeconds: 540,
  memory: "256MiB",
}, async () => {
  const db = getFirestore();

  try {
    logger.info("\n🔄 Starting Scheduled Alerts Check");
    logger.info("----------------------------------------");
    logger.info(`Current Time: ${new Date().toISOString()}`);

    const now = admin.firestore.Timestamp.now();
    const alertsRef = db.collection("scheduledAlerts");

    logger.info("\n🔍 Query Conditions:");
    logger.info("Current Time:", now.toDate().toISOString());
    logger.info("Status: pending");
    logger.info("notificationSent: false");
    logger.info("deleted: false");
    logger.info("instanceState: running");
    logger.info("scheduledTime <= current time");

    // Modified query to match the index structure
    const dueAlerts = await alertsRef
      .where("status", "==", "pending")
      .where("notificationSent", "==", false)
      .where("deleted", "==", false)
      .where("instanceState", "==", "running")
      .where("scheduledTime", "<=", now)
      .get();

    // Log the query parameters
    logger.info("\n🔍 Detailed Query Parameters:");
    logger.info({
      status: "pending",
      notificationSent: false,
      deleted: false,
      instanceState: "running",
      scheduledTimeBefore: now.toDate().toISOString(),
    });

    logger.info(`\n📊 Found ${dueAlerts.size} alerts matching query`);

    // Process each alert
    const validAlerts = dueAlerts.docs.filter((doc) => {
      const data = doc.data();
      logger.info("\n🔍 Checking alert validity:");
      logger.info("Document ID:", doc.id);
      logger.info("Alert Data:");
      logger.info("  • Device Token:", data.fcmToken ? "Present" : "Missing");
      logger.info("  • Token Length:", data.fcmToken?.length || 0);
      logger.info("  • Threshold:", data.threshold);
      logger.info("  • Status:", data.status);
      logger.info("  • Instance State:", data.instanceState);

      // Check if alert has required fields
      if (!data.fcmToken) {
        logger.info("❌ Alert missing FCM token");
        return false;
      }

      if (!data.threshold) {
        logger.info("❌ Alert missing threshold");
        return false;
      }

      return true;
    });

    logger.info(`\n✅ Found ${validAlerts.length} valid alerts to process`);

    // Process valid alerts
    for (const doc of validAlerts) {
      const alertData = doc.data();

      try {
        // Calculate instance runtime
        const launchTime = alertData.launchTime.toDate();
        const currentRuntime = Math.floor(
          (now.toDate().getTime() - launchTime.getTime()) / 60000
        ); // in minutes

        logger.info("\n⏱️ Runtime Analysis:");
        logger.info(`  • Launch Time: ${launchTime.toISOString()}`);
        logger.info(`  • Current Runtime: ${currentRuntime}m`);
        logger.info(`  • Alert Threshold: ${alertData.threshold} minutes`);

        // Check if it's time to send the alert
        if (currentRuntime >= alertData.threshold) {
          // Send notification with device token
          const message: admin.messaging.TokenMessage = {
            token: alertData.fcmToken,
            notification: {
              title: "⏰ Runtime Alert",
              body: `${alertData.instanceName} has been running for ` +
                `${Math.floor(currentRuntime / 60)}h ${currentRuntime % 60}m`,
            },
            data: {
              type: "runtime_alert",
              instanceId: alertData.instanceId,
              instanceName: alertData.instanceName,
              region: alertData.region,
              runtime: String(currentRuntime),
              threshold: String(alertData.threshold),
              launchTime: launchTime.toISOString(),
            },
            apns: {
              payload: {
                aps: {
                  "content-available": 1,
                  "sound": "default",
                  "badge": 1,
                },
              },
              headers: {
                "apns-push-type": "alert",
                "apns-priority": "10",
              },
            },
            android: {
              priority: "high",
            },
          };

          // Send the notification
          await admin.messaging().send(message);
          logger.info("✅ Notification sent successfully");

          // Update alert status
          await doc.ref.update({
            status: "completed",
            notificationSent: true,
            processedAt: now,
          });
          logger.info("✅ Alert status updated to completed");
        } else {
          logger.info("⏳ Alert threshold not yet reached");
        }
      } catch (error) {
        logger.error("❌ Error processing alert:", error);
        // Update alert status to failed
        await doc.ref.update({
          status: "failed",
          error: error instanceof Error ? error.message : "Unknown error",
          processedAt: now,
        });
      }
    }

    logger.info("\n✅ Alert processing completed");
  } catch (error) {
    logger.error("❌ Error in checkScheduledAlerts:", error);
    throw error;
  }
});

// Send push notification
export const sendNotification = onCall(async (request) => {
  const messaging = getMessaging();

  try {
    logger.info("\n📱 Processing notification request");
    logger.info("----------------------------------------");
    logger.info("📊 Notification Data:", request.data);

    const {token, notification, data: messageData, apns} = request.data;

    if (!token || !notification) {
      throw new Error("Missing required notification data");
    }

    const message = {
      token,
      notification,
      data: messageData || {},
      apns: apns || {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    logger.info("📤 Sending message:", message);
    const result = await messaging.send(message);
    logger.info("✅ Message sent successfully:", result);

    return {success: true, messageId: result};
  } catch (error: unknown) {
    if (error instanceof Error) {
      logger.error("❌ Error sending notification:", error);
      throw new Error(`Failed to send notification: ${error.message}`);
    }
    throw error;
  }
});

export const onAlertUpdate = onDocumentWritten("scheduledAlerts/{alertId}",
  async (event) => {
    if (!event.data) return;

    const newData = event.data.after?.data() as AlertData | undefined;
    if (!newData) {
      // Document was deleted
      return;
    }

    try {
      // Only process if status is pending
      if (newData.status === "pending") {
        const now = admin.firestore.Timestamp.now();
        const scheduledTime = newData.scheduledTime.toDate();

        // Check if it's time to process the alert
        if (scheduledTime <= now.toDate()) {
          // Update alert status
          await event.data.after.ref.update({
            status: "completed",
            notificationSent: true,
            processedAt: now,
          });

          // Send notification
          const message = {
            notification: {
              title: "Runtime Alert",
              body: `Instance ${newData.instanceName} has been running for ${newData.hours}h ${newData.minutes}m`,
            },
            data: {
              type: "runtime_alert",
              instanceId: newData.instanceID,
              instanceName: newData.instanceName,
              region: newData.region,
              hours: String(newData.hours),
              minutes: String(newData.minutes),
            },
            topic: "runtime_alerts",
          };

          await admin.messaging().send(message);
          logger.info(`Successfully sent notification for instance ${newData.instanceName}`);
        }
      }
    } catch (error) {
      logger.error("Error in onAlertUpdate:", error);
      // Don't throw error to prevent infinite retries
    }
  });

export const notifyUser = onCall(
  async (request: CallableRequest<NotificationData>) => {
    try {
      const {title, body, token, payload} = request.data;

      const message = {
        notification: {
          title,
          body,
        },
        data: payload || {},
        token,
      };

      const response = await admin.messaging().send(message);
      logger.info("Successfully sent message:", response);

      return {success: true, messageId: response};
    } catch (error) {
      logger.error("Error sending notification:", error);
      throw new HttpsError("internal", "Error sending notification");
    }
  }
);

// Add method to handle instance state changes
export const handleInstanceStateChange = onCall(async (request: CallableRequest<{
  instanceId: string;
  instanceName: string;
  region: string;
  state: string;
  launchTime: string;
}>) => {
  const db = getFirestore();

  try {
    const {instanceId, instanceName, region, state, launchTime} = request.data;

    logger.info("\n🔄 Handling instance state change");
    logger.info(`  • Instance: ${instanceName} (${instanceId})`);
    logger.info(`  • Region: ${region}`);
    logger.info(`  • State: ${state}`);
    logger.info(`  • Launch Time: ${launchTime}`);

    // If state is not running, immediately delete any existing alerts
    if (state !== "running") {
      const msg = `Deleting alerts for stopped instance ${instanceName} (${instanceId}) in region ${region}`;
      logger.info(msg);

      // Delete all alerts for this instance
      const alertsRef = db.collection("scheduledAlerts");
      const existingAlerts = await alertsRef
        .where("instanceId", "==", instanceId)
        .get();

      if (!existingAlerts.empty) {
        const batch = db.batch();
        existingAlerts.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
        logger.info(`  ✅ Deleted ${existingAlerts.size} alerts for stopped instance`);
      } else {
        logger.info("  ℹ️ No alerts found for this instance");
      }
      return {success: true, message: msg};
    }

    // Get alerts for this region
    const alertsRef = db.collection("scheduledAlerts");
    const alerts = await alertsRef
      .where("region", "==", region)
      .where("instanceState", "==", state)
      .get();

    if (alerts.empty) {
      logger.info(`  ℹ️ No alerts configured for region ${region}`);
      return {success: true};
    }

    logger.info(`  📋 Found ${alerts.size} alerts to schedule`);

    const batch = db.batch();
    let scheduledCount = 0;

    for (const doc of alerts.docs) {
      const alertData = doc.data() as AlertData;

      // Calculate threshold in minutes
      const threshold = (alertData.hours * 60) + alertData.minutes;

      // Calculate scheduled time
      const launchTimeDate = new Date(launchTime);
      const scheduledTime = new Date(launchTimeDate.getTime() + threshold * 60000);

      // Create alert document
      const alertId = `${region}_${instanceId}_${Date.now()}`;
      const alertRef = alertsRef.doc(alertId);

      const alertDataToUpdate: Partial<AlertData> = {
        instanceID: instanceId,
        instanceName: instanceName,
        region: region,
        hours: alertData.hours,
        minutes: alertData.minutes,
        scheduledTime: admin.firestore.Timestamp.fromDate(scheduledTime),
        status: "pending",
        notificationSent: false,
        instanceState: state,
        deleted: false,
        launchTime: admin.firestore.Timestamp.fromDate(launchTimeDate),
        fcmToken: alertData.fcmToken,
        createdAt: admin.firestore.Timestamp.now(),
        threshold: threshold,
        type: "runtime_alert",
      };

      batch.set(alertRef, alertDataToUpdate);
      scheduledCount += 1;

      logger.info("  ✅ Scheduled alert:");
      logger.info(`    • ID: ${alertId}`);
      logger.info(`    • Hours: ${alertData.hours}`);
      logger.info(`    • Minutes: ${alertData.minutes}`);
      logger.info(`    • Threshold: ${threshold} minutes`);
      logger.info(`    • Scheduled Time: ${scheduledTime}`);
    }

    // Commit the batch
    await batch.commit();
    logger.info(`  ✅ Successfully scheduled ${scheduledCount} alerts`);

    return {success: true};
  } catch (error) {
    logger.error("❌ Failed to schedule alerts:", error);
    throw new HttpsError("internal", "Failed to schedule alerts");
  }
});

// Update the cleanup function to be more aggressive
export const cleanupStoppedInstanceAlerts = onSchedule({
  schedule: "*/5 * * * *",
  timeoutSeconds: 300,
  memory: "256MiB",
}, async () => {
  const db = getFirestore();

  try {
    logger.info("\n🧹 Starting Cleanup of Stopped Instance Alerts");
    logger.info("----------------------------------------");

    const alertsRef = db.collection("scheduledAlerts");

    // Get all alerts for non-running instances
    const stoppedInstanceAlerts = await alertsRef
      .where("instanceState", "!=", "running")
      .get();

    if (stoppedInstanceAlerts.empty) {
      logger.info("No alerts for stopped instances found");
      return;
    }

    logger.info(`Found ${stoppedInstanceAlerts.size} alerts for stopped instances`);

    const batch = db.batch();
    for (const doc of stoppedInstanceAlerts.docs) {
      // Delete instead of marking as cancelled
      batch.delete(doc.ref);
    }

    await batch.commit();
    logger.info("✅ Successfully deleted alerts for stopped instances");
  } catch (error) {
    logger.error("❌ Error cleaning up stopped instance alerts:", error);
    throw error;
  }
});

// Clean up all alerts
export const cleanupAllAlerts = functions.https.onRequest(async (req, res) => {
  try {
    const alertsRef = admin.firestore().collection("scheduledAlerts");

    // Get alerts with specific statuses, deleted=true, or alert definitions marked as deleted
    const [statusQuery, deletedQuery, deletedDefinitionsQuery, invalidAlertsQuery, duplicateAlertsQuery] = await Promise.all([
      alertsRef.where("status", "in", ["completed", "cancelled", "failed", "deleted"]).get(),
      alertsRef.where("deleted", "==", true).get(),
      alertsRef.where("type", "==", "alert_definition").where("status", "==", "deleted").get(),
      alertsRef.where("status", "==", "pending").get(), // Get pending alerts to check for invalid ones
      alertsRef.orderBy("scheduledTime").get(), // Get all alerts to check for duplicates
    ]);

    // Find duplicate alerts (same instance, same scheduled time)
    const alertsByKey = new Map<string, admin.firestore.QueryDocumentSnapshot[]>();
    duplicateAlertsQuery.docs.forEach((doc) => {
      const data = doc.data();
      const key = `${data.instanceID}_${data.scheduledTime.toDate().getTime()}`;
      const alerts = alertsByKey.get(key) || [];
      alerts.push(doc);
      alertsByKey.set(key, alerts);
    });

    // Keep only the most recent alert for each instance/time combination
    const duplicatesToDelete = new Set<string>();
    alertsByKey.forEach((docs) => {
      if (docs.length > 1) {
        // Sort by creation time, keep the most recent
        docs.sort((a, b) => b.createTime.toDate().getTime() - a.createTime.toDate().getTime());
        // Mark all but the most recent for deletion
        docs.slice(1).forEach((doc) => duplicatesToDelete.add(doc.id));
      }
    });

    // Combine unique documents from all queries
    const docsToDelete = new Set([
      ...statusQuery.docs,
      ...deletedQuery.docs,
      ...deletedDefinitionsQuery.docs,
      // Add invalid alerts (missing FCM token or undefined threshold)
      ...invalidAlertsQuery.docs.filter((doc) => {
        const data = doc.data();
        return !data.fcmToken || data.threshold === undefined || data.threshold <= 0;
      }),
      // Add duplicate alerts
      ...duplicateAlertsQuery.docs.filter((doc) => duplicatesToDelete.has(doc.id)),
    ].map((doc) => doc.id));

    if (docsToDelete.size === 0) {
      logger.info("No alerts found to clean up");
      res.json({success: true, message: "No alerts found to clean up", deletedCount: 0});
      return;
    }

    const batch = admin.firestore().batch();
    docsToDelete.forEach((docId) => {
      batch.delete(alertsRef.doc(docId));
    });

    await batch.commit();
    const deletedCount = docsToDelete.size;
    logger.info(`Successfully deleted ${deletedCount} alerts`);

    res.json({success: true, message: `Successfully deleted ${deletedCount} alerts`, deletedCount});
  } catch (error) {
    logger.error("Error cleaning up alerts:", error);
    res.status(500).json({success: false, error: "Failed to clean up alerts"});
  }
});

// Cleanup old alerts - runs daily at midnight
export const cleanupOldAlerts = onSchedule({
  schedule: "0 0 * * *", // Run daily at midnight
  timeoutSeconds: 540,
  memory: "256MiB",
}, async () => {
  try {
    logger.info("\n🧹 Starting Daily Alert Cleanup");
    logger.info("----------------------------------------");

    const db = getFirestore();
    const batch = db.batch();
    let documentsToDelete = 0;

    // Get timestamp for 24 hours ago
    const oneDayAgo = new Date();
    oneDayAgo.setHours(oneDayAgo.getHours() - 24);
    const cutoffTime = admin.firestore.Timestamp.fromDate(oneDayAgo);

    // Query for old completed/cancelled/failed alerts
    const oldAlertsQuery = db.collection("scheduledAlerts")
      .where("type", "in", ["runtime_alert", "auto_stop_alert"])
      .where("status", "in", ["completed", "cancelled", "failed", "deleted"])
      .where("updatedAt", "<=", cutoffTime);

    const oldAlerts = await oldAlertsQuery.get();
    logger.info(`Found ${oldAlerts.size} old alerts to clean up`);

    oldAlerts.forEach((doc) => {
      batch.delete(doc.ref);
      documentsToDelete++;
    });

    // Query for orphaned alerts (no FCM token or invalid state)
    const orphanedAlertsQuery = db.collection("scheduledAlerts")
      .where("type", "in", ["runtime_alert", "auto_stop_alert"])
      .where("status", "==", "pending")
      .where("notificationSent", "==", false);

    const orphanedAlerts = await orphanedAlertsQuery.get();
    orphanedAlerts.forEach((doc) => {
      const data = doc.data();
      const isOrphaned = !data.fcmToken ||
        data.instanceState !== "running" ||
        !data.scheduledTime;
      if (isOrphaned) {
        batch.delete(doc.ref);
        documentsToDelete++;
      }
    });

    // Commit the batch if there are documents to delete
    if (documentsToDelete > 0) {
      await batch.commit();
      logger.info(`✅ Successfully deleted ${documentsToDelete} notifications older than 24 hours`);
    } else {
      logger.info("No notifications to clean up");
    }
  } catch (error) {
    logger.error("❌ Error in notification cleanup:", error);
    throw error;
  }
});

// Manual trigger for cleanup
export const triggerCleanup = onCall(async () => {
  try {
    logger.info("\n🧹 Starting Manual Notification Cleanup");
    logger.info("----------------------------------------");

    const db = getFirestore();
    const batch = db.batch();
    let documentsToDelete = 0;

    // Get timestamp for 24 hours ago
    const oneDayAgo = new Date();
    oneDayAgo.setHours(oneDayAgo.getHours() - 24);
    const cutoffTime = admin.firestore.Timestamp.fromDate(oneDayAgo);

    // Query for old completed/cancelled/failed alerts
    const oldAlertsQuery = db.collection("scheduledAlerts")
      .where("type", "in", ["runtime_alert", "auto_stop_alert"])
      .where("status", "in", ["completed", "cancelled", "failed", "deleted"])
      .where("updatedAt", "<=", cutoffTime);

    const oldAlerts = await oldAlertsQuery.get();
    logger.info(`Found ${oldAlerts.size} old notifications to clean up`);

    oldAlerts.forEach((doc) => {
      batch.delete(doc.ref);
      documentsToDelete++;
    });

    // Query for orphaned alerts (no FCM token or invalid state)
    const orphanedAlertsQuery = db.collection("scheduledAlerts")
      .where("type", "in", ["runtime_alert", "auto_stop_alert"])
      .where("status", "==", "pending")
      .where("notificationSent", "==", false);

    const orphanedAlerts = await orphanedAlertsQuery.get();
    orphanedAlerts.forEach((doc) => {
      const data = doc.data();
      const isOrphaned = !data.fcmToken ||
        data.instanceState !== "running" ||
        !data.scheduledTime;
      if (isOrphaned) {
        batch.delete(doc.ref);
        documentsToDelete++;
      }
    });

    // Commit the batch if there are documents to delete
    if (documentsToDelete > 0) {
      await batch.commit();
      logger.info(`✅ Successfully deleted ${documentsToDelete} notifications older than 24 hours`);
      return {success: true, deletedCount: documentsToDelete};
    } else {
      logger.info("No notifications to clean up");
      return {success: true, deletedCount: 0};
    }
  } catch (error) {
    logger.error("❌ Error in notification cleanup:", error);
    throw new HttpsError("internal", "Failed to clean up notifications");
  }
});
