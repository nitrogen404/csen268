import 'package:cloud_firestore/cloud_firestore.dart';

class Chain {
  final String id;
  final String title;

  // These remain formatted strings purely for UI compatibility
  final String days;     // e.g., "30 days"
  final String members;  // e.g., "2 members"

  final double progress; // 0.0 - 1.0, computed from totalDaysCompleted / durationDays
  final String code;

  // Backend / logic fields
  final String ownerId;
  final int durationDays;
  final int memberCount;
  final int currentStreak;        // group streak (consecutive days with activity)
  final int totalDaysCompleted;   // number of days the group has completed

  Chain({
    required this.id,
    required this.title,
    required this.days,
    required this.members,
    required this.progress,
    required this.code,
    required this.ownerId,
    required this.durationDays,
    required this.memberCount,
    required this.currentStreak,
    required this.totalDaysCompleted,
  });

  factory Chain.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final duration = (data['durationDays'] ?? 0) as int;
    final memberCount = (data['memberCount'] ?? 1) as int;
    final completed = (data['totalDaysCompleted'] ?? 0) as int;

    double computedProgress = 0.0;
    if (duration > 0 && completed > 0) {
      computedProgress = (completed / duration).clamp(0.0, 1.0);
    }

    return Chain(
      id: doc.id,
      title: data['title'] ?? '',

      // UI strings
      days: '$duration days',
      members: '$memberCount member${memberCount == 1 ? '' : 's'}',

      // Computed progress
      progress: computedProgress,

      code: data['code'] ?? '',
      ownerId: data['ownerId'] ?? '',

      durationDays: duration,
      memberCount: memberCount,
      currentStreak: (data['currentStreak'] ?? 0) as int,
      totalDaysCompleted: completed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'durationDays': durationDays,
      'memberCount': memberCount,
      'code': code,
      'ownerId': ownerId,
      'currentStreak': currentStreak,
      'totalDaysCompleted': totalDaysCompleted,
      // no need to store `days`, `members`, or `progress` – they are derived
    };
  }
}