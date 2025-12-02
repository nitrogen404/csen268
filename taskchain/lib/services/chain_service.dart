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

    await newDoc.set({
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
      'lastGroupCheckInDate': null,
      'lastCompletionStatus': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await newDoc.collection('members').doc(ownerId).set({
      'userId': ownerId,
      'email': ownerEmail,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
      'lastCheckInDate': null,
      'streak': 0,
    });

    final userRef = _firestore.collection('users').doc(ownerId);
    final userSnap = await userRef.get();
    final today = _dateKeyUtc(now);

    final update = {'email': ownerEmail};
    if (!userSnap.exists || userSnap.data()?['firstChainJoinDate'] == null) {
      update['firstChainJoinDate'] = today;
    }

    await userRef.set(update, SetOptions(merge: true));

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
    });

    await chainRef.update({
      'memberCount': FieldValue.increment(1),
    });

    final userRef = _firestore.collection('users').doc(userId);
    final userSnap = await userRef.get();
    final nowKey = _dateKeyUtc(DateTime.now().toUtc());

    final update = {'email': userEmail};
    if (!userSnap.exists || userSnap.data()?['firstChainJoinDate'] == null) {
      update['firstChainJoinDate'] = nowKey;
    }

    await userRef.set(update, SetOptions(merge: true));

    return true;
  }

  // ---------------------------------------------------------------------------
  // FIXED GROUP STREAK LOGIC
  // ---------------------------------------------------------------------------
  Future<void> completeDailyActivity({
    required String userId,
    required String userEmail,
    required String chainId,
    required String chainTitle,
  }) async {
    final now = DateTime.now().toUtc();
    final today = _dateKeyUtc(now);

    final chainRef = _firestore.collection('chains').doc(chainId);
    final memberRef = chainRef.collection('members').doc(userId);

    final membersSnap = await chainRef.collection('members').get();
    final totalMembers = membersSnap.docs.length;

    await _firestore.runTransaction((tx) async {
      final chainSnap = await tx.get(chainRef);
      final chainData = chainSnap.data() ?? {};

      final memberSnap = await tx.get(memberRef);
      final memberData = memberSnap.data() ?? {};

      final lastCheckIn = memberData['lastCheckInDate'] as String?;
      if (lastCheckIn == today) throw 'Already checked in.';

      final lastGroupCheckIn = chainData['lastGroupCheckInDate'] as String?;
      final lastCompleted = chainData['lastCompletionStatus'] == true;

      int groupStreak = chainData['currentStreak'] ?? 0;

      // reset streak if yesterday was not completed
      if (lastGroupCheckIn != today) {
        if (lastGroupCheckIn != null && lastCompleted == false) {
          groupStreak = 0;
        }
      }

      // update current member
      tx.update(memberRef, {'lastCheckInDate': today});

      // count how many members checked in today
      int checked = 0;
      for (final m in membersSnap.docs) {
        final data = m.data();
        final last = data['lastCheckInDate'] as String?;
        if (m.id == userId) {
          checked++;
        } else if (last == today) {
          checked++;
        }
      }

      // all members checked in → success day
      if (checked == totalMembers) {
        groupStreak++;

        tx.update(chainRef, {
          'currentStreak': groupStreak,
          'totalDaysCompleted': (chainData['totalDaysCompleted'] ?? 0) + 1,
          'lastGroupCheckInDate': today,
          'lastCompletionStatus': true,
        });
      } else {
        // still waiting for others
        tx.update(chainRef, {
          'lastGroupCheckInDate': today,
          'lastCompletionStatus': false,
        });
      }
    });
  }

  // ---------------------------------------------------------------------------

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