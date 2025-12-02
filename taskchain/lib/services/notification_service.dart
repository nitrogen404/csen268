import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Initialize notifications (call once on app start)
  Future<void> initialize() async {
    // Request permission for notifications
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else {
      print('User declined or has not accepted notification permission');
    }

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap (can be wired to navigation if needed)
        print('Notification tapped: ${response.payload}');
      },
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Get FCM token and store it in Firestore for Cloud Functions
    final token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');
    
    // Store token in Firestore for Cloud Functions to use
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      } catch (e) {
        print('Error storing FCM token: $e');
      }
    }
    
    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('FCM Token refreshed: $newToken');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'fcmToken': newToken}).catchError((e) {
          print('Error updating FCM token: $e');
        });
      }
    });
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message: ${message.notification?.title}');

    // Prefer rich data payload if available so we can surface
    // chain name, sender name, and message text clearly.
    final data = message.data;
    final senderId = (data['senderId'] as String?)?.trim();
    final sender = (data['senderName'] as String?)?.trim();
    final text = (data['text'] as String?)?.trim();
    String? chainTitle = (data['chainTitle'] as String?)?.trim();
    final chainId = (data['chainId'] as String?)?.trim();

    // If this message was sent by the currently signed-in user,
    // do not show a system notification. This prevents users from
    // getting notified about their own messages.
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null &&
        senderId != null &&
        senderId.isNotEmpty &&
        senderId == currentUid) {
      return;
    }

    // If chainTitle is missing but we have chainId, look it up so
    // the banner can still show a nice chain name.
    if ((chainTitle == null || chainTitle.isEmpty) &&
        chainId != null &&
        chainId.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('chains')
            .doc(chainId)
            .get();
        final data = snap.data();
        if (data != null) {
          final t = data['title'] as String?;
          if (t != null && t.trim().isNotEmpty) {
            chainTitle = t.trim();
          }
        }
      } catch (e) {
        // Non-fatal; fall back to whatever we have.
        print('Failed to fetch chain title for notification: $e');
      }
    }

    // Clean, minimal banner layout:
    //   Title: Chain name
    //   Body : Sender: message text
    String title;
    String body;

    final hasChainTitle = chainTitle != null && chainTitle.isNotEmpty;
    final hasSender = sender != null && sender.isNotEmpty;
    final hasText = text != null && text.isNotEmpty;

    if (hasChainTitle) {
      title = chainTitle!;
      if (hasSender && hasText) {
        body = '$sender: $text';
      } else if (hasSender) {
        body = '$sender sent a message';
      } else if (hasText) {
        body = text!;
      } else {
        body = message.notification?.body ?? 'New message in $chainTitle';
      }
    } else if (hasSender) {
      title = sender!;
      if (hasText) {
        body = text!;
      } else {
        body = message.notification?.body ?? 'New message';
      }
    } else {
      // Last-resort generic formatting
      title = message.notification?.title ?? 'New message';
      body = message.notification?.body ?? (text ?? '');
    }

    await _showLocalNotification(
      title: title,
      body: body,
      payload: message.data.toString(),
    );
  }

  // Handle background messages that opened the app
  void _handleBackgroundMessage(RemoteMessage message) {
    print('Background message opened: ${message.notification?.title}');
    // TODO: Navigate to relevant screen based on message.data if desired.
  }

  // Public helper for simple, in-app system notifications.
  Future<void> showSubscriptionNotification(String chainTitle) async {
    await _showLocalNotification(
      title: '🔔 Subscribed to "$chainTitle"',
      body: 'You will now receive updates from this chain.',
    );
  }

  /// Show a notification summarizing unread inbox items
  /// (friend requests + chain invites).
  Future<void> showInboxNotification(int unreadCount) async {
    if (unreadCount <= 0) return;
    await _showLocalNotification(
      title: '📥 Inbox update',
      body:
          '$unreadCount new item${unreadCount == 1 ? '' : 's'} in your TaskChain inbox',
      payload: 'inbox:$unreadCount',
    );
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'taskchain_channel',
      'TaskChain',
      channelDescription: 'TaskChain notifications',
      // Beautiful, modern, branded Android banner configuration.
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      colorized: true,
      color: Color(0xFF4CAF50),
      largeIcon: const DrawableResourceAndroidBitmap('taskchain_logo'),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        htmlFormatContentTitle: true,
        summaryText: 'TaskChain',
      ),
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Get FCM token
  Future<String?> getToken() async {
    return _firebaseMessaging.getToken();
  }

  // Subscribe to topic (used for per-chain notifications)
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }
}

