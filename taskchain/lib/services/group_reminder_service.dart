import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'airia_service.dart';
import 'user_service.dart';
import 'notification_service.dart';

class GroupReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AiriaService _airiaService = AiriaService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

  /// Send personalized reminders to group members who haven't checked in yet
  /// Called when someone completes their check-in
  Future<void> remindGroupMembers({
    required String chainId,
    required String chainTitle,
    required String completedByUserId,
    required String completedByUserName,
  }) async {
    try {
      final chainRef = _firestore.collection('chains').doc(chainId);
      final membersSnap = await chainRef.collection('members').get();
      
      final today = _dateKeyUtc(DateTime.now().toUtc());
      final membersToRemind = <String>[];
      final memberNames = <String, String>{};

      // Find members who haven't checked in today
      for (final memberDoc in membersSnap.docs) {
        final memberData = memberDoc.data();
        final memberUserId = memberData['userId'] as String? ?? memberDoc.id;
        final lastCheckIn = memberData['lastCheckInDate'] as String?;
        final memberEmail = memberData['email'] as String? ?? '';
        
        // Skip the person who just checked in
        if (memberUserId == completedByUserId) continue;
        
        // Skip if they already checked in today
        if (lastCheckIn == today) continue;
        
        membersToRemind.add(memberUserId);
        memberNames[memberUserId] = memberEmail;
      }

      // If no one needs reminding, return
      if (membersToRemind.isEmpty) return;

      // Get user profiles for personalized messages
      final userProfiles = <String, Map<String, dynamic>>{};
      for (final userId in membersToRemind) {
        try {
          final profile = await _userService.getUserProfile(userId);
          final data = profile.data() as Map<String, dynamic>? ?? {};
          userProfiles[userId] = {
            'displayName': data['displayName'] ?? memberNames[userId]?.split('@').first ?? 'Member',
            'currentStreak': data['currentStreak'] ?? 0,
            'longestStreak': data['longestStreak'] ?? 0,
          };
        } catch (e) {
          // Use default if profile fetch fails
          userProfiles[userId] = {
            'displayName': memberNames[userId]?.split('@').first ?? 'Member',
            'currentStreak': 0,
            'longestStreak': 0,
          };
        }
      }

      // Store personalized reminders in Firestore for each member
      // Cloud Function will send FCM notifications with personalized messages
      for (final userId in membersToRemind) {
        final userProfile = userProfiles[userId]!;
        final userName = userProfile['displayName'] as String;
        
        try {
          // Generate personalized reminder message for each user
          final personalizedMessage = await _generatePersonalizedReminder(
            userName: userName,
            chainTitle: chainTitle,
            completedByUserName: completedByUserName,
            currentStreak: userProfile['currentStreak'] as int,
            longestStreak: userProfile['longestStreak'] as int,
          );

          // Store reminder in Firestore
          // Cloud Function will automatically send FCM notification with this personalized message
          await _storeReminder(
            chainId: chainId,
            chainTitle: chainTitle,
            message: personalizedMessage,
            targetUserId: userId,
          );
        } catch (e) {
          print('Error storing reminder for $userId: $e');
        }
      }
    } catch (e) {
      print('Error in remindGroupMembers: $e');
    }
  }

  /// Generate a personalized reminder message using Airia API
  Future<String> _generatePersonalizedReminder({
    required String userName,
    required String chainTitle,
    required String completedByUserName,
    required int currentStreak,
    required int longestStreak,
  }) async {
    try {
      final prompt = '''
$completedByUserName just completed their check-in for "$chainTitle"! 

Generate a short, encouraging reminder message (max 80 characters) for $userName to check in. 
Personalize it based on:
- Their current streak: $currentStreak days
- Their longest streak: $longestStreak days
- The fact that $completedByUserName already checked in

Make it motivational and friendly. Just return the message text, no extra formatting.
''';

      final response = await _airiaService.sendReminderMessage(prompt);
      
      // Clean up markdown and limit length
      String message = response.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
      message = message.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
      message = message.trim();
      
      if (message.length > 80) {
        message = '${message.substring(0, 77)}...';
      }
      
      return message.isNotEmpty 
          ? message 
          : '$completedByUserName checked in! Your turn to keep the streak going! 🔥';
    } catch (e) {
      print('Error generating personalized reminder: $e');
      return '$completedByUserName checked in! Your turn to keep the streak going! 🔥';
    }
  }

  /// Store reminder in Firestore
  /// Cloud Function will automatically send FCM notification with the personalized message
  Future<void> _storeReminder({
    required String chainId,
    required String chainTitle,
    required String message,
    required String targetUserId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('groupReminders')
          .add({
        'chainId': chainId,
        'chainTitle': chainTitle,
        'message': message, // Personalized message for this specific user
        'type': 'group_checkin_reminder',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'sent': false, // Cloud Function will mark as sent after sending FCM
      });
      
      print('Stored personalized reminder for user $targetUserId: $message');
    } catch (e) {
      print('Error storing reminder: $e');
    }
  }


  /// Helper to format date as yyyy-MM-dd
  String _dateKeyUtc(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

