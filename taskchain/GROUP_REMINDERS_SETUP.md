# Group Reminders Setup

## Overview

When a user completes their check-in, personalized reminder notifications are sent to other group members who haven't checked in yet. These reminders use AI-generated personalized messages based on each member's progress and streaks.

## How It Works

1. **User completes check-in** → `ChainService.completeDailyActivity()` is called
2. **GroupReminderService identifies** members who haven't checked in today
3. **Personalized messages** are generated using Airia API for each member
4. **Reminders are stored** in Firestore at `users/{userId}/groupReminders`
5. **Cloud Function** listens and sends FCM notifications to users

## Cloud Functions Required

**IMPORTANT**: FCM notifications cannot be sent directly from the client app. You need Cloud Functions to send notifications.

You need to create TWO Cloud Functions:

### 1. Group Reminders Function

Listens to `users/{userId}/groupReminders` collection and sends FCM notifications:

1. **Listens to** `users/{userId}/groupReminders` collection
2. **Gets user's FCM token** from `users/{userId}/fcmToken`
3. **Sends FCM notification** using Firebase Admin SDK
4. **Marks reminder as sent** (`sent: true`)

### 2. Message Notifications Function (if not already set up)

Listens to `chains/{chainId}/messages` collection and sends FCM notifications to chain topic:

1. **Listens to** `chains/{chainId}/messages` collection
2. **Sends FCM notification** to topic `chain_{chainId}`
3. All members subscribed to the topic will receive the notification

### Example Cloud Functions (Node.js)

#### Function 1: Send Group Reminders

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendGroupReminder = functions.firestore
  .document('users/{userId}/groupReminders/{reminderId}')
  .onCreate(async (snap, context) => {
    const reminder = snap.data();
    
    // Skip if already sent
    if (reminder.sent) return null;
    
    const userId = context.params.userId;
    
    // Get user's FCM token
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token for user ${userId}`);
      return null;
    }
    
    // Send notification
    const message = {
      notification: {
        title: reminder.chainTitle,
        body: reminder.message,
      },
      data: {
        type: 'group_reminder',
        chainId: reminder.chainId,
        chainTitle: reminder.chainTitle,
      },
      token: fcmToken,
      android: {
        priority: 'high',
        notification: {
          channelId: 'taskchain_reminders',
          sound: 'default',
        },
      },
    };
    
    try {
      await admin.messaging().send(message);
      
      // Mark as sent
      await snap.ref.update({ sent: true });
      
      console.log(`Reminder sent to user ${userId}`);
    } catch (error) {
      console.error(`Error sending reminder: ${error}`);
    }
    
    return null;
  });
```

#### Function 2: Send Message Notifications (for system reminders)

```javascript
exports.sendMessageNotification = functions.firestore
  .document('chains/{chainId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const chainId = context.params.chainId;
    
    // Skip if message is from system or if sender is checking their own message
    if (message.isSystemMessage && message.type === 'group_reminder') {
      // Send to chain topic
      const topic = `chain_${chainId}`;
      
      const notification = {
        notification: {
          title: message.chainTitle || 'TaskChain Reminder',
          body: message.text,
        },
        data: {
          type: 'group_reminder',
          chainId: chainId,
          chainTitle: message.chainTitle || '',
        },
        topic: topic,
        android: {
          priority: 'high',
          notification: {
            channelId: 'taskchain_reminders',
            sound: 'default',
          },
        },
      };
      
      try {
        await admin.messaging().send(notification);
        console.log(`Reminder notification sent to topic ${topic}`);
      } catch (error) {
        console.error(`Error sending notification: ${error}`);
      }
    }
    
    return null;
  });
```

## FCM Token Storage

Users need to store their FCM tokens in Firestore. Add this to your app initialization:

```dart
// In main.dart or notification service
final token = await FirebaseMessaging.instance.getToken();
await FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .update({'fcmToken': token});
```

## Airia Pipeline

The reminder pipeline ID is configured in `airia_service.dart`:
- Pipeline ID: `216ac243-7276-4a55-8ade-bd1cb32941bb`
- Optimized for generating short, personalized reminder messages

## Testing

1. Have two users join the same chain
2. User A completes check-in
3. Check Firestore: `users/{userBId}/groupReminders` should have a new document
4. Cloud Function should send FCM notification to User B
5. User B receives personalized reminder notification

