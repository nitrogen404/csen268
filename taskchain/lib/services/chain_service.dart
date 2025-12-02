import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chain.dart';

class ChainService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    final now = DateTime.now().toUtc();
    final start = startDate ?? now;
    final startTs = Timestamp.fromDate(start);

    final chainData = {
      'title': title.trim(),
      'ownerId': ownerId,
      'code': code,
      'frequency': frequency,
      'theme': theme,
      'startDate': startTs,
      'durationDays': durationDays,
      'memberCount': 1,
      'currentStreak': 0,
      'totalDaysCompleted': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await newDoc.set(chainData);

    await newDoc.collection('members').doc(ownerId).set({
      'userId': ownerId,
      'email': ownerEmail,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
      'lastCheckInDate': null,
      'streak': 0,
      'isActiveToday': false,
    });

    final userRef = _firestore.collection('users').doc(ownerId);
    final userSnap = await userRef.get();
    final nowKey = _dateKeyUtc(now);

    final userUpdate = <String, dynamic>{
      'email': ownerEmail,
    };

    if (!userSnap.exists || userSnap.data()?['firstChainJoinDate'] == null) {
      userUpdate['firstChainJoinDate'] = nowKey;
    }

    await userRef.set(userUpdate, SetOptions(merge: true));

    return Chain(
      id: newDoc.id,
      title: title.trim(),
      days: '$durationDays days',
      members: '1 member',
      progress: 0.0,
      code: code,
      ownerId: ownerId,
      durationDays: durationDays,
      memberCount: 1,
      currentStreak: 0,
      totalDaysCompleted: 0,
      theme: theme,
    );
  }

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
        if (chainSnap.exists) {
          chains.add(Chain.fromFirestore(chainSnap));
        }
      }

      chains.sort((a, b) => a.title.compareTo(b.title));
      return chains;
    });
  }

  Stream<int> streamJoinedChainCount(String userId) {
    return _firestore
        .collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

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

  Future<bool> joinChainByCode({
    required String userId,
    required String userEmail,
    required String code,
  }) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw 'Please enter a code.';
    }

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
    final ownerId = chainData['ownerId'] ?? '';

    final memberDocRef = chainRef.collection('members').doc(userId);
    final existing = await memberDocRef.get();

    if (existing.exists) return false;

    await memberDocRef.set({
      'userId': userId,
      'email': userEmail,
      'role': userId == ownerId ? 'owner' : 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      'lastCheckInDate': null,
      'streak': 0,
      'isActiveToday': false,
    });

    await chainRef.update({
      'memberCount': FieldValue.increment(1),
    });

    final userRef = _firestore.collection('users').doc(userId);
    final userSnap = await userRef.get();
    final nowKey = _dateKeyUtc(DateTime.now().toUtc());

    final userUpdate = <String, dynamic>{
      'email': userEmail,
    };

    if (!userSnap.exists || userSnap.data()?['firstChainJoinDate'] == null) {
      userUpdate['firstChainJoinDate'] = nowKey;
    }

    await userRef.set(userUpdate, SetOptions(merge: true));

    return true;
  }

  Future<void> completeDailyActivity({
    required String userId,
    required String userEmail,
    required String chainId,
    required String chainTitle,
  }) async {
    final now = DateTime.now().toUtc();
    final todayKey = _dateKeyUtc(now);

    final chainRef = _firestore.collection('chains').doc(chainId);
    final memberRef = chainRef.collection('members').doc(userId);
    final userRef = _firestore.collection('users').doc(userId);
    final activityRef = userRef.collection('activity').doc();

    await _firestore.runTransaction((tx) async {
      final chainSnap = await tx.get(chainRef);
      final memberSnap = await tx.get(memberRef);
      final userSnap = await tx.get(userRef);

      final chainData = chainSnap.data() ?? <String, dynamic>{};
      final memberData = memberSnap.data() ?? <String, dynamic>{};
      final userData = userSnap.data() ?? <String, dynamic>{};

      // Per-chain once-per-day rule
      final lastCheckInStr = memberData['lastCheckInDate'] as String?;
      if (lastCheckInStr == todayKey) {
        throw 'You have already completed today\'s activity for this chain.';
      }

      // Per-chain personal streak
      int memberStreak = (memberData['streak'] ?? 0) as int;
      if (lastCheckInStr != null) {
        final last = DateTime.parse(lastCheckInStr);
        final lastDate = DateTime.utc(last.year, last.month, last.day);
        final todayDate = DateTime.utc(now.year, now.month, now.day);
        final diff = todayDate.difference(lastDate).inDays;

        memberStreak = diff == 1 ? memberStreak + 1 : 1;
      } else {
        memberStreak = 1;
      }

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

      // Group streak and chain progress
      int groupStreak = (chainData['currentStreak'] ?? 0) as int;
      int totalCompleted = (chainData['totalDaysCompleted'] ?? 0) as int;
      final lastGroupStr = chainData['lastGroupCheckInDate'] as String?;

      if (lastGroupStr != todayKey) {
        if (lastGroupStr != null) {
          final last = DateTime.parse(lastGroupStr);
          final lastDate = DateTime.utc(last.year, last.month, last.day);
          final todayDate = DateTime.utc(now.year, now.month, now.day);
          final diff = todayDate.difference(lastDate).inDays;

          groupStreak = diff == 1 ? groupStreak + 1 : 1;
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

      // Global user stats
      int totalCheckIns = (userData['checkIns'] ?? 0) as int;
      int daysActive = (userData['daysActive'] ?? 0) as int;
      int currentStreak = (userData['currentStreak'] ?? 0) as int;
      int longestStreak = (userData['longestStreak'] ?? 0) as int;

      final lastActiveStr = userData['lastActiveDate'] as String?;
      String? firstJoinStr = userData['firstChainJoinDate'] as String?;

      // Fallback for old users with no firstChainJoinDate
      if (firstJoinStr == null) {
        firstJoinStr = todayKey;
      }

      bool isNewActiveDay = lastActiveStr != todayKey;

      if (isNewActiveDay) {
        if (lastActiveStr != null) {
          final last = DateTime.parse(lastActiveStr);
          final lastDate = DateTime.utc(last.year, last.month, last.day);
          final todayDate = DateTime.utc(now.year, now.month, now.day);
          final diff = todayDate.difference(lastDate).inDays;

          currentStreak = diff == 1 ? currentStreak + 1 : 1;
        } else {
          currentStreak = 1;
        }

        daysActive += 1;

        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
      }

      // Total days since first chain join (Option B)
      int totalDays = 1;
      try {
        final first = DateTime.parse(firstJoinStr);
        final firstDate = DateTime.utc(first.year, first.month, first.day);
        final todayDate = DateTime.utc(now.year, now.month, now.day);
        final diffTotal = todayDate.difference(firstDate).inDays;
        totalDays = diffTotal + 1;
        if (totalDays < 1) totalDays = 1;
      } catch (_) {
        totalDays = daysActive > 0 ? daysActive : 1;
      }

      double successRate = 0.0;
      if (totalDays > 0 && daysActive > 0) {
        successRate = (daysActive / totalDays) * 100.0;
      }

      totalCheckIns += 1;

      final userUpdate = <String, dynamic>{
        'email': userEmail,
        'checkIns': totalCheckIns,
        'lastActiveDate': todayKey,
        'firstChainJoinDate': firstJoinStr,
      };

      if (isNewActiveDay) {
        userUpdate['daysActive'] = daysActive;
        userUpdate['currentStreak'] = currentStreak;
        userUpdate['longestStreak'] = longestStreak;
        userUpdate['successRate'] = successRate;
      }

      tx.set(userRef, userUpdate, SetOptions(merge: true));

      tx.set(activityRef, {
        'chainId': chainId,
        'chainTitle': chainTitle,
        'description': 'Completed $chainTitle',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

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

  String _dateKeyUtc(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}