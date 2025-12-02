# Cloud Functions Setup Guide

This guide will help you set up and deploy Cloud Functions for TaskChain notifications.

## Prerequisites

1. **Node.js** (version 18 or higher)
   - Check: `node --version`
   - Download: https://nodejs.org/

2. **Firebase CLI**
   - Install: `npm install -g firebase-tools`
   - Login: `firebase login`

3. **Firebase Project**
   - Make sure you have access to the Firebase project: `taskchain-64312`

## Setup Steps

### 1. Install Dependencies

```bash
cd functions
npm install
cd ..
```

### 2. Initialize Firebase (if not already done)

```bash
firebase init
```

When prompted:
- Select **Functions** (use arrow keys and spacebar to select)
- Select your existing Firebase project: `taskchain-64312`
- Use JavaScript (not TypeScript)
- Say **No** to ESLint (or Yes if you want it)
- Say **No** to installing dependencies (we'll do it manually)

### 3. Deploy Functions

```bash
firebase deploy --only functions
```

Or deploy specific functions:

```bash
firebase deploy --only functions:sendGroupReminder
firebase deploy --only functions:sendMessageNotification
```

### 4. Verify Deployment

Check the Firebase Console:
1. Go to **Functions** section
2. You should see:
   - `sendGroupReminder`
   - `sendMessageNotification`

## Functions Overview

### `sendGroupReminder`

- **Trigger**: New document in `users/{userId}/groupReminders`
- **Purpose**: Sends personalized FCM notifications to users when they receive a group reminder
- **Flow**:
  1. User A completes check-in
  2. App creates reminder documents in Firestore
  3. This function triggers for each reminder
  4. Fetches user's FCM token
  5. Sends FCM notification
  6. Marks reminder as `sent: true`

### `sendMessageNotification`

- **Trigger**: New document in `chains/{chainId}/messages`
- **Purpose**: Sends FCM notifications to all chain members when a new message is posted
- **Flow**:
  1. New message added to chain
  2. Function sends notification to chain topic (`chain_{chainId}`)
  3. All members subscribed to the topic receive the notification
  4. Client-side filters out notifications for messages sent by current user

## Testing

### Test Group Reminders

1. Have two users join the same chain
2. User A completes check-in and chooses "Yes" to remind others
3. Check Firebase Console → Firestore:
   - `users/{userBId}/groupReminders` should have a new document
4. Check Firebase Console → Functions → Logs:
   - Should see "Successfully sent reminder to user..."
5. User B should receive a notification

### Test Message Notifications

1. User A sends a message in a chain
2. Check Firebase Console → Functions → Logs:
   - Should see "Successfully sent message notification to topic..."
3. User B (subscribed to chain topic) should receive a notification

## Troubleshooting

### Function not triggering

- Check Firebase Console → Functions → Logs for errors
- Verify Firestore security rules allow writes
- Check that the document structure matches what the function expects

### Notifications not received

- Verify FCM token is stored in `users/{userId}/fcmToken`
- Check device notification settings
- Verify user is subscribed to chain topic (`chain_{chainId}`)
- Check Firebase Console → Cloud Messaging → Reports

### Deployment errors

- Make sure you're logged in: `firebase login`
- Check Node.js version: `node --version` (should be 18+)
- Try: `firebase deploy --only functions --debug`

## Local Development

To test functions locally:

```bash
cd functions
npm run serve
```

This starts the Firebase emulator. You can test functions locally before deploying.

## Monitoring

- **Firebase Console → Functions**: View function execution logs
- **Firebase Console → Cloud Messaging → Reports**: View notification delivery stats
- **Firebase Console → Firestore**: Monitor document creation/updates

## Cost Considerations

- Cloud Functions: Free tier includes 2 million invocations/month
- FCM: Free for unlimited notifications
- Firestore: Pay per read/write operation

For a small app, you should stay well within free tiers.

