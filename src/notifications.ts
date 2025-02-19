import * as admin from 'firebase-admin';
import { logger } from 'firebase-functions';

interface NotificationData {
  title: string;
  body: string;
  data?: {
    instanceId?: string;
    instanceName?: string;
    runtime?: string;
    threshold?: string;
    alertId?: string;
    [key: string]: string | undefined;
  };
}

export async function sendNotification(token: string, notification: NotificationData): Promise<string> {
  try {
    logger.info("\n📱 Sending notification");
    logger.info("----------------------------------------");
    logger.info("Notification details:");
    logger.info(`  • Title: ${notification.title}`);
    logger.info(`  • Body: ${notification.body}`);
    logger.info(`  • Token: ${token}`);
    
    if (notification.data) {
      logger.info("  • Data:", notification.data);
    }

    const message: admin.messaging.Message = {
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: notification.data,
      token: token,
      apns: {
        payload: {
          aps: {
            'content-available': 1,
            sound: 'default',
            badge: 1
          }
        },
        headers: {
          'apns-push-type': 'alert',
          'apns-priority': '10'
        }
      },
      android: {
        priority: 'high'
      }
    };

    const response = await admin.messaging().send(message);
    logger.info("✅ Notification sent successfully:", response);
    return response;
  } catch (error) {
    logger.error("❌ Error sending notification:", error);
    throw error;
  }
} 