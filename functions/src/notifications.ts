import * as admin from "firebase-admin";
import {logger} from "firebase-functions";

export interface NotificationData {
  title: string;
  body: string;
  token: string;
  data?: {
    [key: string]: string;
  };
}

export async function sendNotification(token: string, notification: NotificationData): Promise<string> {
  try {
    logger.info("\n📱 Preparing to send notification");
    logger.info("----------------------------------------");
    logger.info("Notification details:");
    logger.info(`  • Title: ${notification.title}`);
    logger.info(`  • Body: ${notification.body}`);
    logger.info(`  • Token: ${token}`);

    if (notification.data) {
      logger.info("  • Data:", notification.data);
    }

    // Validate token
    if (!token || token.length < 10) {
      throw new Error("Invalid FCM token");
    }

    // Ensure all data values are strings
    const sanitizedData = notification.data ? 
      Object.entries(notification.data).reduce((acc, [key, value]) => {
        acc[key] = String(value);
        return acc;
      }, {} as {[key: string]: string}) : undefined;

    // Construct a simpler message first
    const fcmMessage: admin.messaging.Message = {
      token,
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: sanitizedData,
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
              title: notification.title,
              body: notification.body
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

    // Add optional fields only if they exist
    if (notification.data?.instanceId) {
      fcmMessage.apns = {
        ...fcmMessage.apns,
        headers: {
          ...fcmMessage.apns?.headers,
          "apns-collapse-id": `${notification.data.instanceId}_${Date.now()}`
        }
      };
    }

    const maxRetries = 3;
    let lastError: any;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        logger.info(`\n📱 Sending notification (Attempt ${attempt} of ${maxRetries})`);
        const response = await admin.messaging().send(fcmMessage);
        logger.info("✅ Notification sent successfully:", response);
        return response;
      } catch (error: any) {
        lastError = error;
        logger.error(`❌ Error sending notification (Attempt ${attempt}):`, error);
        
        // Handle specific error cases
        if (error.code === "messaging/invalid-argument" ||
            error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered") {
          logger.error(`Fatal error (${error.code}):`, error.message);
          throw error; // Don't retry for these errors
        }
        
        // For other errors, retry with backoff
        if (attempt < maxRetries) {
          const delay = Math.min(1000 * Math.pow(2, attempt - 1), 10000);
          logger.info(`Waiting ${delay}ms before retry...`);
          await new Promise(resolve => setTimeout(resolve, delay));
        }
      }
    }
    
    throw new Error(`Failed to send notification after ${maxRetries} attempts: ${lastError?.message}`);
  } catch (error: any) {
    logger.error("❌ Fatal error in sendNotification:", error);
    throw error;
  }
}
