import 'package:cloud_firestore/cloud_firestore.dart';

class Chain {
  final String id; // Firestore document ID
  final String title;
  final String days;
  final String members;
  final double progress;
  final String code; // unique join code

  Chain({
    required this.id,
    required this.title,
    required this.days,
    required this.members,
    required this.progress,
    required this.code,
  });

  factory Chain.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chain(
      id: doc.id,
      title: data['title'] ?? '',
      days: data['days'] ?? '',
      members: data['members'] ?? '',
      progress: (data['progress'] is num) ? (data['progress'] as num).toDouble() : 0.0,
      code: data['code'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'days': days,
      'members': members,
      'progress': progress,
      'code': code,
    };
  }
}


