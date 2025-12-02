import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  Future<void> ensureUserProfile(User user) async {
    final docRef = _usersCol.doc(user.uid);
    final doc = await docRef.get();
    
    if (!doc.exists) {
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
        'premiumExpiresAt': null,
        'premiumType': null,
        'coins': 0,
        'purchasedThemes': [],
        'createdAt': Timestamp.fromDate(now),

        // Global stats
        'totalChains': 0,            // not used for UI now, but kept for compatibility
        'checkIns': 0,
        'currentStreak': 0,
        'longestStreak': 0,
        'successRate': 0.0,
        'daysActive': 0,

        // Baseline for successRate (Option B)
        'firstChainJoinDate': null,  // "yyyy-MM-dd" set on first chain join/create
        'lastActiveDate': null,      // "yyyy-MM-dd" of last day with any check-in

        // AI chatbot tracking
        'aiMessagesToday': 0,
        'aiMessagesDate': null,  // "yyyy-MM-dd" format
      });
    } else {
      // Ensure existing users have coins field initialized
      final data = doc.data() ?? {};
      if (!data.containsKey('coins')) {
        await docRef.set({'coins': 0}, SetOptions(merge: true));
      }
      // Ensure purchasedThemes field exists
      if (!data.containsKey('purchasedThemes')) {
        await docRef.set({'purchasedThemes': []}, SetOptions(merge: true));
      }
      // Ensure premium fields exist
      if (!data.containsKey('isPremium')) {
        await docRef.set({'isPremium': false}, SetOptions(merge: true));
      }
    }
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
    String? profilePictureUrl,
  }) async {
    final Map<String, dynamic> update = {};
    if (displayName != null) update['displayName'] = displayName;
    if (bio != null) update['bio'] = bio;
    if (location != null) update['location'] = location;
    if (profilePictureUrl != null) {
      update['profilePictureUrl'] = profilePictureUrl;
    }

    if (update.isEmpty) return;

    await _usersCol.doc(userId).set(update, SetOptions(merge: true));
  }

  Future<String> uploadProfilePicture({
    required String userId,
    required File imageFile,
  }) async {
    final String fileName =
        "${DateTime.now().millisecondsSinceEpoch}_$userId.jpg";
    final String storagePath = "profile_pictures/$userId/$fileName";
    final Reference ref = FirebaseStorage.instance.ref(storagePath);

    final uploadTask = ref.putFile(
      imageFile,
      SettableMetadata(
        contentType: "image/jpeg",
        customMetadata: {
          "uploadedBy": userId,
        },
      ),
    );

    await uploadTask;
    final downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  }
}