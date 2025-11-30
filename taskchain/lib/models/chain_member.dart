import 'package:cloud_firestore/cloud_firestore.dart';

class ChainMember {
  final String userId;
  final String email;
  final String role; // "owner" or "member"
  final DateTime joinedAt;
  final DateTime? lastCheckIn;
  final int streak;
  final bool isActiveToday;

  ChainMember({
    required this.userId,
    required this.email,
    required this.role,
    required this.joinedAt,
    required this.lastCheckIn,
    required this.streak,
    required this.isActiveToday,
  });

  factory ChainMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final joinedTs = data['joinedAt'] as Timestamp?;
    final lastTs = data['lastCheckIn'] as Timestamp?;

    return ChainMember(
      userId: data['userId'] ?? doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'member',

      // Safe timestamp handling
      joinedAt: joinedTs != null ? joinedTs.toDate() : DateTime.now(),
      lastCheckIn: lastTs != null ? lastTs.toDate() : null,

      streak: data['streak'] ?? 0,
      isActiveToday: data['isActiveToday'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastCheckIn': lastCheckIn != null
          ? Timestamp.fromDate(lastCheckIn!)
          : null,
      'streak': streak,
      'isActiveToday': isActiveToday,
    };
  }
}