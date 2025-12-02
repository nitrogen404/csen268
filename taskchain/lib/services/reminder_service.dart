import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../services/airia_service.dart';
import '../services/auth_service.dart';

class ReminderService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AiriaService _airiaService = AiriaService();
  final AuthService _authService = AuthService();
  
  static const String _reminderChannelId = 'taskchain_reminders';
  static const String _reminderChannelName = 'TaskChain Reminders';
  
  bool _isInitialized = false;
  final List<int> _scheduledNotificationIds = [];

  /// Initialize the reminder service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone data
    tz.initializeTimeZones();
    
    _isInitialized = true;
  }

  /// Get a personalized reminder message from AI
  /// Uses a dedicated Airia pipeline for reminders
  Future<String> _getPersonalizedReminderMessage() async {
    try {
      // Call Airia API with a reminder-specific prompt
      final response = await _airiaService.sendReminderMessage(
        'Generate a short, encouraging reminder message (max 100 characters) to check in on my chains. Make it personalized based on my progress and current streaks. Be motivational and friendly. Just return the message text, no extra formatting.',
      );
      
      // Extract just the message text, remove markdown if present
      String message = response.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
      message = message.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
      message = message.trim();
      
      // Limit to 100 characters for notification
      if (message.length > 100) {
        message = '${message.substring(0, 97)}...';
      }
      
      return message.isNotEmpty ? message : 'Time to check in on your chains! Keep your streak going! 🔥';
    } catch (e) {
      print('Error getting personalized reminder: $e');
      // Fallback to default message
      return 'Time to check in on your chains! Keep your streak going! 🔥';
    }
  }

  /// Schedule reminders every 3 hours
  /// Fetches one personalized message per day to avoid too many API calls
  Future<void> scheduleReminders({bool reschedule = false}) async {
    final user = _authService.currentUser;
    if (user == null) return;

    await initialize();

    // Cancel existing reminders if rescheduling
    if (reschedule) {
      await cancelAllReminders();
    }

    // Schedule reminders for the next 7 days (every 3 hours)
    // Starting from the next 3-hour mark
    final now = tz.TZDateTime.now(tz.local);
    final nextReminderTime = _getNextReminderTime(now);
    
    int notificationId = 1000; // Start from 1000 to avoid conflicts
    
    // Fetch one personalized message per day to reduce API calls
    String? dailyMessage;
    int currentDay = -1;
    
    // Schedule for the next 7 days (56 reminders = 7 days * 8 reminders per day)
    for (int day = 0; day < 7; day++) {
      for (int reminder = 0; reminder < 8; reminder++) {
        final reminderTime = nextReminderTime.add(Duration(
          days: day,
          hours: reminder * 3,
        ));
        
        // Skip if the time is in the past
        if (reminderTime.isBefore(now)) continue;
        
        // Fetch new personalized message once per day
        if (day != currentDay) {
          dailyMessage = await _getPersonalizedReminderMessage();
          currentDay = day;
          // Small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        await _scheduleNotification(
          id: notificationId,
          scheduledDate: reminderTime,
          title: 'TaskChain Reminder',
          body: dailyMessage ?? 'Time to check in on your chains! Keep your streak going! 🔥',
        );
        
        _scheduledNotificationIds.add(notificationId);
        notificationId++;
      }
    }
    
    print('Scheduled ${_scheduledNotificationIds.length} reminder notifications');
  }

  /// Get the next 3-hour mark from now
  tz.TZDateTime _getNextReminderTime(tz.TZDateTime now) {
    final hour = now.hour;
    final nextHour = ((hour ~/ 3) + 1) * 3;
    
    if (nextHour >= 24) {
      // Next day at midnight (0:00)
      return tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        0,
        0,
      );
    } else {
      // Same day at next 3-hour mark
      return tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        nextHour,
        0,
      );
    }
  }

  /// Schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      _reminderChannelName,
      channelDescription: 'Personalized reminders to check in on your chains',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      colorized: true,
      color: const Color(0xFF7B61FF),
      largeIcon: const DrawableResourceAndroidBitmap('taskchain_logo'),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
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

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancel all scheduled reminders
  Future<void> cancelAllReminders() async {
    for (final id in _scheduledNotificationIds) {
      await _localNotifications.cancel(id);
    }
    _scheduledNotificationIds.clear();
    print('Cancelled all reminder notifications');
  }

  /// Check if reminders are enabled and schedule/cancel accordingly
  Future<void> updateReminders(bool enabled) async {
    if (enabled) {
      await scheduleReminders(reschedule: true);
    } else {
      await cancelAllReminders();
    }
  }
}

