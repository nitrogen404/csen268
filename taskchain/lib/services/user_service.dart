import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  Future<void> ensureUserProfile(User user) async {
    final docRef = _usersCol.doc(user.uid);
    final doc = await docRef.get();
    if (doc.exists) return;

    final now = DateTime.now();
    final email = user.email ?? '';
    final defaultName =
        email.isNotEmpty ? email.split('@').first : 'TaskChain User';

    await docRef.set({
      'displayName': defaultName,
      'email': email,
      'bio': '',
      'location': '',
      'isPremium': false,
      'createdAt': Timestamp.fromDate(now),
      'totalChains': 0,
      'longestStreak': 0,
      'checkIns': 0,
      'successRate': 0,
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile(
      String userId) {
    return _usersCol.doc(userId).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(
      String userId) {
    return _usersCol.doc(userId).get();
  }

  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? location,
  }) async {
    final Map<String, dynamic> update = {};
    if (displayName != null) update['displayName'] = displayName;
    if (bio != null) update['bio'] = bio;
    if (location != null) update['location'] = location;

    if (update.isEmpty) return;

    await _usersCol.doc(userId).set(update, SetOptions(merge: true));
  }
}