import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chain.dart';

class ChainService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new chain and add it to the owner's joined chains.
  /// Returns the created [Chain].
  Future<Chain> createChain({
    required String ownerId,
    required String ownerEmail,
    required String title,
    required String frequency,
    required DateTime? startDate,
    required int durationDays,
    required String theme,
  }) async {
    if (title.trim().isEmpty) {
      throw 'Please enter a habit name.';
    }

    // Generate a unique join code
    final code = await _generateUniqueCode();

    final chainsRef = _firestore.collection('chains');
    final newDoc = chainsRef.doc();

    final now = DateTime.now();
    final start = startDate ?? now;

    final chainData = {
      'title': title.trim(),
      'days': '$durationDays days',
      'members': '1 member',
      'progress': 0.0,
      'code': code,
      'ownerId': ownerId,
      'frequency': frequency,
      'startDate': Timestamp.fromDate(start),
      'durationDays': durationDays,
      'theme': theme,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await newDoc.set(chainData);

    // Also add to user's joined chains
    final userChainRef = _firestore
        .collection('users')
        .doc(ownerId)
        .collection('chains')
        .doc(newDoc.id);

    await userChainRef.set({
      'chainId': newDoc.id,
      'title': chainData['title'],
      'days': chainData['days'],
      'members': chainData['members'],
      'progress': chainData['progress'],
      'code': chainData['code'],
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Add owner to chain members subcollection
    final membersRef =
        _firestore.collection('chains').doc(newDoc.id).collection('members');
    await membersRef.doc(ownerId).set({
      'userId': ownerId,
      'email': ownerEmail,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return Chain(
      id: newDoc.id,
      title: chainData['title'] as String,
      days: chainData['days'] as String,
      members: chainData['members'] as String,
      progress: (chainData['progress'] as num).toDouble(),
      code: chainData['code'] as String,
    );
  }

  /// Join a chain by its unique code.
  /// Creates/updates an entry under users/{uid}/chains/{chainId}
  Future<void> joinChainByCode({
    required String userId,
    required String userEmail,
    required String code,
  }) async {
    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      throw 'Please enter a code.';
    }

    // Find chain by code
    final query = await _firestore
        .collection('chains')
        .where('code', isEqualTo: trimmedCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw 'No chain found for this code.';
    }

    final chainDoc = query.docs.first;
    final chain = Chain.fromFirestore(chainDoc);

    final userChainRef =
        _firestore.collection('users').doc(userId).collection('chains').doc(chain.id);

    // If already joined, just update metadata
    await userChainRef.set({
      'chainId': chain.id,
      'title': chain.title,
      'days': chain.days,
      'members': chain.members,
      'progress': chain.progress,
      'code': chain.code,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Add to chain members subcollection
    final membersRef =
        _firestore.collection('chains').doc(chain.id).collection('members');
    await membersRef.doc(userId).set({
      'userId': userId,
      'email': userEmail,
      'role': userId == chainDoc['ownerId'] ? 'owner' : 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream all chains the user has joined from users/{uid}/chains
  Stream<List<Chain>> streamJoinedChains(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chains')
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Chain(
          id: data['chainId'] ?? doc.id,
          title: data['title'] ?? '',
          days: data['days'] ?? '',
          members: data['members'] ?? '',
          progress: (data['progress'] is num)
              ? (data['progress'] as num).toDouble()
              : 0.0,
          code: data['code'] ?? '',
        );
      }).toList();
    });
  }

  /// Complete today's activity for a user in a given chain.
  /// - Only increments streaks once per calendar day (per user per chain).
  /// - Updates:
  ///   - users/{uid}/chains/{chainId}.currentStreak & lastCheckInDate
  ///   - chains/{chainId}.groupStreak & lastGroupCheckInDate
  ///   - users/{uid}.checkIns, currentStreak, longestStreak
  ///   - users/{uid}/activity/{autoId} recent-activity entry
  Future<void> completeDailyActivity({
    required String userId,
    required String userEmail,
    required String chainId,
    required String chainTitle,
  }) async {
    final now = DateTime.now().toUtc();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final userChainRef =
        _firestore.collection('users').doc(userId).collection('chains').doc(chainId);
    final chainRef = _firestore.collection('chains').doc(chainId);
    final userRef = _firestore.collection('users').doc(userId);
    final activityRef = userRef.collection('activity').doc();

    await _firestore.runTransaction((tx) async {
      final userChainSnap = await tx.get(userChainRef);
      final chainSnap = await tx.get(chainRef);
      final userSnap = await tx.get(userRef);

      final userChainData = userChainSnap.data() ?? {};
      final chainData = chainSnap.data() ?? {};
      final userData = userSnap.data() ?? {};

      // ---- per-user once-per-day enforcement ----
      final lastCheckIn = userChainData['lastCheckInDate'] as String?;
      if (lastCheckIn == todayKey) {
        throw 'You have already completed today\'s activity for this chain.';
      }

      // ---- per-user streak ----
      int currentStreak = (userChainData['currentStreak'] ?? 0) as int;
      if (lastCheckIn != null) {
        final last = DateTime.parse(lastCheckIn);
        final lastDate = DateTime.utc(last.year, last.month, last.day);
        final diff = now.difference(lastDate).inDays;
        if (diff == 1) {
          currentStreak += 1;
        } else {
          currentStreak = 1;
        }
      } else {
        currentStreak = 1;
      }

      // ---- group streak (once per day globally) ----
      int groupStreak = (chainData['groupStreak'] ?? 0) as int;
      final lastGroup = chainData['lastGroupCheckInDate'] as String?;
      if (lastGroup != todayKey) {
        if (lastGroup != null) {
          final last = DateTime.parse(lastGroup);
          final lastDate = DateTime.utc(last.year, last.month, last.day);
          final diff = now.difference(lastDate).inDays;
          groupStreak = (diff == 1) ? groupStreak + 1 : 1;
        } else {
          groupStreak = 1;
        }
      }

      // ---- user global stats ----
      final totalCheckIns = (userData['checkIns'] ?? 0) as int;
      int longestStreak = (userData['longestStreak'] ?? 0) as int;
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      tx.set(userChainRef, {
        'lastCheckInDate': todayKey,
        'currentStreak': currentStreak,
      }, SetOptions(merge: true));

      tx.set(chainRef, {
        'lastGroupCheckInDate': todayKey,
        'groupStreak': groupStreak,
      }, SetOptions(merge: true));

      tx.set(userRef, {
        'checkIns': totalCheckIns + 1,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      }, SetOptions(merge: true));

      tx.set(activityRef, {
        'chainId': chainId,
        'chainTitle': chainTitle,
        'description': 'Completed $chainTitle',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Generate a random 6-character join code and ensure it is unique.
  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();

    while (true) {
      final code = List.generate(
        6,
        (_) => chars[rand.nextInt(chars.length)],
      ).join();

      final existing = await _firestore
          .collection('chains')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        return code;
      }
      // else retry
    }
  }
}

