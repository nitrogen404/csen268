const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function: Send Group Reminder Notifications
 * 
 * Listens to new documents in users/{userId}/groupReminders
 * Sends FCM notification to the user when a reminder is created
 */
exports.sendGroupReminder = functions.firestore
  .document('users/{userId}/groupReminders/{reminderId}')
  .onCreate(async (snap, context) => {
    const reminder = snap.data();
    
    // Skip if already sent
    if (reminder.sent) {
      console.log(`Reminder ${context.params.reminderId} already sent, skipping`);
      return null;
    }
    
    const userId = context.params.userId;
    
    try {
      // Get user's FCM token
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();
      
      if (!userDoc.exists) {
        console.log(`User ${userId} not found`);
        return null;
      }
      
      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;
      
      if (!fcmToken) {
        console.log(`No FCM token for user ${userId}`);
        return null;
      }
      
      // Send FCM notification
      const message = {
        notification: {
          title: reminder.chainTitle || 'TaskChain Reminder',
          body: reminder.message || 'Time to check in!',
        },
        data: {
          type: 'group_reminder',
          chainId: reminder.chainId || '',
          chainTitle: reminder.chainTitle || '',
          reminderId: context.params.reminderId,
        },
        token: fcmToken,
        android: {
          priority: 'high',
          notification: {
            channelId: 'taskchain_channel',
            sound: 'default',
            color: '#4CAF50',
            icon: 'taskchain_logo',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };
      
      const response = await admin.messaging().send(message);
      console.log(`Successfully sent reminder to user ${userId}: ${response}`);
      
      // Mark as sent
      await snap.ref.update({ 
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return null;
    } catch (error) {
      console.error(`Error sending reminder to user ${userId}:`, error);
      
      // Mark as failed (optional - you might want to retry later)
      await snap.ref.update({ 
        sent: false,
        error: error.message,
      });
      
      return null;
    }
  });

/**
 * Cloud Function: Send Message Notifications
 * 
 * Listens to new messages in chains/{chainId}/messages
 * Sends FCM notification to all members subscribed to the chain topic
 * Skips notifications for messages sent by the current user (handled client-side)
 */
exports.sendMessageNotification = functions.firestore
  .document('chains/{chainId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const chainId = context.params.chainId;
    
    // Skip system messages that are group reminders (they're handled by sendGroupReminder)
    if (message.isSystemMessage && message.type === 'group_reminder') {
      // Send to chain topic for immediate notification
      const topic = `chain_${chainId}`;
      
      const notification = {
        notification: {
          title: message.chainTitle || message.text.split('🔔')[1]?.trim() || 'TaskChain Reminder',
          body: message.text.replace('🔔', '').trim(),
        },
        data: {
          type: 'group_reminder',
          chainId: chainId,
          chainTitle: message.chainTitle || '',
          messageId: context.params.messageId,
        },
        topic: topic,
        android: {
          priority: 'high',
          notification: {
            channelId: 'taskchain_channel',
            sound: 'default',
            color: '#4CAF50',
            icon: 'taskchain_logo',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };
      
      try {
        const response = await admin.messaging().send(notification);
        console.log(`Successfully sent reminder notification to topic ${topic}: ${response}`);
      } catch (error) {
        console.error(`Error sending notification to topic ${topic}:`, error);
      }
      
      return null;
    }
    
    // For regular chat messages, send to chain topic
    // The client-side notification service will filter out messages from the current user
    const topic = `chain_${chainId}`;
    
    const notification = {
      notification: {
        title: message.chainTitle || 'TaskChain',
        body: message.senderName 
          ? '${message.senderName}: ${message.text || ""}'
          : (message.text || 'New message'),
      },
      data: {
        type: 'message',
        chainId: chainId,
        chainTitle: message.chainTitle || '',
        messageId: context.params.messageId,
        senderId: message.senderId || '',
        senderName: message.senderName || '',
      },
      topic: topic,
      android: {
        priority: 'high',
        notification: {
          channelId: 'taskchain_channel',
          sound: 'default',
          color: '#4CAF50',
          icon: 'taskchain_logo',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };
    
    try {
      const response = await admin.messaging().send(notification);
      console.log(`Successfully sent message notification to topic ${topic}: ${response}`);
    } catch (error) {
      console.error(`Error sending notification to topic ${topic}:`, error);
    }
    
    return null;
  });

