import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String userId;
  final String displayName;
  final String email;
  final String bio;
  final String location;

  // Stats
  final int totalChains;
  final int longestStreak;
  final int checkIns;
  final int successRate;

  UserProfile({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.bio,
    required this.location,
    required this.totalChains,
    required this.longestStreak,
    required this.checkIns,
    required this.successRate,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserProfile(
      userId: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      bio: data['bio'] ?? '',
      location: data['location'] ?? '',
      totalChains: data['totalChains'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      checkIns: data['checkIns'] ?? 0,
      successRate: data['successRate'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'location': location,
      'totalChains': totalChains,
      'longestStreak': longestStreak,
      'checkIns': checkIns,
      'successRate': successRate,
    };
  }
}