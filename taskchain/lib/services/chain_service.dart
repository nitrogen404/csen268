import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chain.dart';

class ChainService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new chain and add the owner as the first member.
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

    final code = await _generateUniqueCode();
    final chainsRef = _firestore.collection('chains');
    final newDoc = chainsRef.doc();

    final now = DateTime.now();
    final start = startDate ?? now;

    final chainData = {
      'title': title.trim(),
      'ownerId': ownerId,
      'code': code,
      'frequency': frequency,
      'theme': theme,
      'startDate': Timestamp.fromDate(start),
      'durationDays': durationDays,
      'memberCount': 1,
      'currentStreak': 0,
      'totalDaysCompleted': 0,
      'createdAt': FieldValue.serverTimestamp(),
      // lastGroupCheckInDate is added lazily when first check-in happens
    };

    // Create chain document
    await newDoc.set(chainData);

    // Add owner as chain member
    final membersRef = newDoc.collection('members');
    await membersRef.doc(ownerId).set({
      'userId': ownerId,
      'email': ownerEmail,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
      'lastCheckInDate': null,
      'streak': 0,
      'isActiveToday': false,
    });

    // Update user aggregate stats (safe even if profile already exists)
    final userRef = _firestore.collection('users').doc(ownerId);
    await userRef.set({
      'email': ownerEmail,
      'totalChains': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Build Chain instance for UI
    final duration = durationDays;
    const memberCount = 1;
    const totalCompleted = 0;
    const currentStreak = 0;

    return Chain(
      id: newDoc.id,
      title: title.trim(),
      days: '$duration days',
      members: '$memberCount member',
      progress: 0.0,
      code: code,
      ownerId: ownerId,
      durationDays: duration,
      memberCount: memberCount,
      currentStreak: currentStreak,
      totalDaysCompleted: totalCompleted,
      theme: theme,
    );
  }

  /// Stream all chains the user is a member of.
  ///
  /// Uses the members subcollection instead of users/{uid}/chains.
  Stream<List<Chain>> streamJoinedChains(String userId) {
    return _firestore
        .collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final chains = <Chain>[];

      for (final memberDoc in snapshot.docs) {
        final chainRef = memberDoc.reference.parent.parent;
        if (chainRef == null) continue;

        final chainSnap = await chainRef.get();
        if (!chainSnap.exists) continue;

        chains.add(Chain.fromFirestore(chainSnap));
      }

      // Optional: sort by creation time descending if needed
      // For now, sort alphabetically by title to keep it stable.
      chains.sort((a, b) => a.title.compareTo(b.title));
      return chains;
    });
  }

  /// Get only the chain IDs the user has joined.
  Future<List<String>> getJoinedChainIds(String userId) async {
    final snapshot = await _firestore
        .collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .get();

    final ids = <String>{};
    for (final doc in snapshot.docs) {
      final chainRef = doc.reference.parent.parent;
      if (chainRef != null) {
        ids.add(chainRef.id);
      }
    }
    return ids.toList();
  }

  /// Join a chain using a join code.
  ///
  /// Returns `true` if the user was newly added to the chain, and `false`
  /// if they were already a member (in which case no changes are made).
  Future<bool> joinChainByCode({
    required String userId,
    required String userEmail,
    required String code,
  }) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw 'Please enter a code.';
    }

    // Find chain by code
    final query = await _firestore
        .collection('chains')
        .where('code', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw 'No chain found for this code.';
    }

    final chainDoc = query.docs.first;
    final chainRef = chainDoc.reference;
    final chainData = chainDoc.data();
    final ownerId = chainData['ownerId'] as String? ?? '';

    final membersRef = chainRef.collection('members');
    final memberDocRef = membersRef.doc(userId);
    final existing = await memberDocRef.get();
    if (existing.exists) {
      // Already a member; nothing to do
      return false;
    }

    // Add as new member
    await memberDocRef.set({
      'userId': userId,
      'email': userEmail,
      'role': userId == ownerId ? 'owner' : 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      'lastCheckInDate': null,
      'streak': 0,
      'isActiveToday': false,
    });

    // Increment memberCount on chain
    await chainRef.update({
      'memberCount': FieldValue.increment(1),
    });

    // Ensure user doc exists at least with email
    final userRef = _firestore.collection('users').doc(userId);
    await userRef.set({
      'email': userEmail,
    }, SetOptions(merge: true));

    return true;
  }

  /// Complete today's activity for this user and chain.
  ///
  /// - Per-user: one check-in per day per chain.
  /// - Updates per-user streak in the members subcollection.
  /// - Updates group streak and totalDaysCompleted on the chain.
  /// - Updates overall stats in users/{uid}.
  /// - Logs activity in users/{uid}/activity.
  Future<void> completeDailyActivity({
    required String userId,
    required String userEmail,
    required String chainId,
    required String chainTitle,
  }) async {
    final now = DateTime.now().toUtc();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final chainRef = _firestore.collection('chains').doc(chainId);
    final memberRef = chainRef.collection('members').doc(userId);
    final userRef = _firestore.collection('users').doc(userId);
    final activityRef = userRef.collection('activity').doc();

    await _firestore.runTransaction((tx) async {
      final chainSnap = await tx.get(chainRef);
      final memberSnap = await tx.get(memberRef);
      final userSnap = await tx.get(userRef);

      final chainData = chainSnap.data() ?? {};
      final memberData = memberSnap.data() ?? {};
      final userData = userSnap.data() ?? {};

      // --- Per-user once per day rule ---
      final lastCheckInStr = memberData['lastCheckInDate'] as String?;
      if (lastCheckInStr == todayKey) {
        throw 'You have already completed today\'s activity for this chain.';
      }

      // --- Per-user streak (per chain) ---
      int memberStreak = (memberData['streak'] ?? 0) as int;
      if (lastCheckInStr != null) {
        final last = DateTime.parse(lastCheckInStr);
        final lastDate = DateTime.utc(last.year, last.month, last.day);
        final diff = now.difference(lastDate).inDays;
        if (diff == 1) {
          memberStreak += 1;
        } else {
          memberStreak = 1;
        }
      } else {
        memberStreak = 1;
      }

      // Update member document
      tx.set(
        memberRef,
        {
          'userId': userId,
          'email': userEmail,
          'lastCheckInDate': todayKey,
          'streak': memberStreak,
          'isActiveToday': true,
        },
        SetOptions(merge: true),
      );

      // --- Group streak + total days completed ---
      int groupStreak = (chainData['currentStreak'] ?? 0) as int;
      final lastGroupStr = chainData['lastGroupCheckInDate'] as String?;
      int totalCompleted = (chainData['totalDaysCompleted'] ?? 0) as int;

      if (lastGroupStr != todayKey) {
        if (lastGroupStr != null) {
          final last = DateTime.parse(lastGroupStr);
          final lastDate = DateTime.utc(last.year, last.month, last.day);
          final diff = now.difference(lastDate).inDays;
          groupStreak = (diff == 1) ? groupStreak + 1 : 1;
        } else {
          groupStreak = 1;
        }
        totalCompleted += 1;
      }

      tx.set(
        chainRef,
        {
          'currentStreak': groupStreak,
          'lastGroupCheckInDate': todayKey,
          'totalDaysCompleted': totalCompleted,
        },
        SetOptions(merge: true),
      );

      // --- User global stats (profile) ---
      final totalCheckIns = (userData['checkIns'] ?? 0) as int;
      int longestStreak = (userData['longestStreak'] ?? 0) as int;
      // For now, compare with this chain-specific streak
      if (memberStreak > longestStreak) {
        longestStreak = memberStreak;
      }

      tx.set(
        userRef,
        {
          'email': userEmail,
          'checkIns': totalCheckIns + 1,
          'currentStreak': memberStreak,
          'longestStreak': longestStreak,
        },
        SetOptions(merge: true),
      );

      // --- Activity log ---
      tx.set(activityRef, {
        'chainId': chainId,
        'chainTitle': chainTitle,
        'description': 'Completed $chainTitle',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Generate a unique 6-character join code.
  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();

    while (true) {
      final code =
          List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();

      final exists = await _firestore
          .collection('chains')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (exists.docs.isEmpty) return code;
    }
  }
}