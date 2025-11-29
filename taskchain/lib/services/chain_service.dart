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

