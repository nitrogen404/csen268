import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chain.dart';
import 'group_reminder_service.dart';
import 'user_service.dart';
import 'shop_service.dart';
import 'currency_service.dart';

class ChainService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ShopService _shopService = ShopService();
  final CurrencyService _currencyService = CurrencyService();

  // Chain limit constants
  static const int FREE_USER_CHAIN_LIMIT = 2;
  static const int PREMIUM_USER_CHAIN_LIMIT = -1; // -1 means unlimited

  /// Get current chain count for a user
  Future<int> getCurrentChainCount(String userId) async {
    final snapshot = await _firestore
        .collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.length;
  }

  /// Check if user is premium
  Future<bool> isUserPremium(String userId) async {
    return await _shopService.isPremiumActive(userId);
  }

  /// Check if user can create/join more chains
  Future<void> checkChainLimit(String userId) async {
    // Check if user is premium
    final isPremium = await isUserPremium(userId);

    // Premium users have unlimited chains
    if (isPremium) return;

    // Free users: check current chain count
    final currentCount = await getCurrentChainCount(userId);
    if (currentCount >= FREE_USER_CHAIN_LIMIT) {
      throw 'Free users can only have $FREE_USER_CHAIN_LIMIT active chains. Upgrade to Premium for unlimited chains!';
    }
  }

  Future<Chain> createChain({
    required String ownerId,
    required String ownerEmail,
    required String title,
    required String frequency,
    required DateTime? startDate,
    required int durationDays,
    required String theme,
  }) async {
    // Check chain limit BEFORE creating
    await checkChainLimit(ownerId);

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
    // Check chain limit BEFORE joining
    await checkChainLimit(userId);

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
    bool sendReminders = true,
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
        // Check if this day was already completed (prevents double-counting when new members join mid-day)
        final alreadyCompletedToday = 
            lastGroupCheckIn == today && lastCompleted == true;
        
        if (!alreadyCompletedToday) {
          // First time completing today - increment progress and streak
          groupStreak++;

          tx.update(chainRef, {
            'currentStreak': groupStreak,
            'totalDaysCompleted': (chainData['totalDaysCompleted'] ?? 0) + 1,
            'lastGroupCheckInDate': today,
            'lastCompletionStatus': true,
          });
        } else {
          // Day already completed - just ensure status is set (no progress/streeak increment)
          // This handles the case where a new member joins mid-day and checks in
          // We don't increment totalDaysCompleted or streak again for the same day
          tx.update(chainRef, {
            'lastGroupCheckInDate': today,
            'lastCompletionStatus': true,
          });
        }
      } else {
        // still waiting for others
        tx.update(chainRef, {
          'lastGroupCheckInDate': today,
          'lastCompletionStatus': false,
        });
      }
    });

    // Update user's global stats after check-in
    try {
      await _updateUserStatsAfterCheckIn(userId, today);
    } catch (e) {
      // Don't fail check-in if stats update fails
      print('Error updating user stats: $e');
    }

    // Award coins for check-in
    try {
      await _currencyService.earnCoinsFromCheckIn(userId);

      // Get user's current streak and award milestone coins if applicable
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      final currentStreak = (userData['currentStreak'] as int?) ?? 0;
      await _currencyService.earnCoinsFromStreak(userId, currentStreak);
    } catch (e) {
      // Don't fail check-in if coin earning fails
      print('Error awarding coins: $e');
    }

    // Send reminders to other members who haven't checked in yet
    if (sendReminders) {
      try {
        final userService = UserService();
        final userProfile = await userService.getUserProfile(userId);
        final userData = userProfile.data() as Map<String, dynamic>? ?? {};
        final userName = userData['displayName'] as String? ?? 
                        userEmail.split('@').first;

        final reminderService = GroupReminderService();
        await reminderService.remindGroupMembers(
          chainId: chainId,
          chainTitle: chainTitle,
          completedByUserId: userId,
          completedByUserName: userName,
        );
      } catch (e) {
        // Don't fail the check-in if reminder sending fails
        print('Error sending group reminders: $e');
      }
    }

    // Check if chain is completed and award completion coins
    try {
      final chainDoc = await chainRef.get();
      final chainData = chainDoc.data() ?? {};
      final totalDaysCompleted = (chainData['totalDaysCompleted'] as int?) ?? 0;
      final durationDays = (chainData['durationDays'] as int?) ?? 0;

      if (durationDays > 0 && totalDaysCompleted >= durationDays) {
        // Check if we've already awarded completion coins
        final completionAwarded = chainData['completionCoinsAwarded'] as bool? ?? false;
        if (!completionAwarded) {
          // Award coins to all members
          final allMembers = await chainRef.collection('members').get();
          for (final memberDoc in allMembers.docs) {
            final memberUserId = memberDoc.data()['userId'] as String? ?? memberDoc.id;
            await _currencyService.earnCoinsFromChainCompletion(memberUserId);
          }

          // Mark as awarded
          await chainRef.update({'completionCoinsAwarded': true});
        }
      }
    } catch (e) {
      // Don't fail check-in if completion coin check fails
      print('Error checking chain completion: $e');
    }
  }

  /// Update chain theme
  /// Only the chain owner can change the theme
  Future<void> updateChainTheme({
    required String chainId,
    required String theme,
    required String requesterId,
  }) async {
    final chainRef = _firestore.collection('chains').doc(chainId);
    final chainDoc = await chainRef.get();

    if (!chainDoc.exists) {
      throw 'Chain not found';
    }

    final data = chainDoc.data() as Map<String, dynamic>? ?? {};
    final ownerId = data['ownerId'] as String? ?? '';

    if (ownerId != requesterId) {
      throw 'Only the chain owner can change the theme';
    }

    await chainRef.update({'theme': theme});
  }

  /// Leave a chain
  /// Members can leave chains, but owners must delete the chain instead
  Future<void> leaveChain({
    required String chainId,
    required String userId,
  }) async {
    final chainRef = _firestore.collection('chains').doc(chainId);
    final chainDoc = await chainRef.get();

    if (!chainDoc.exists) {
      throw 'Chain not found';
    }

    final data = chainDoc.data() as Map<String, dynamic>? ?? {};
    final ownerId = data['ownerId'] as String? ?? '';

    // Owners cannot leave - they must delete the chain
    if (ownerId == userId) {
      throw 'Chain owners cannot leave. Please delete the chain instead.';
    }

    final memberRef = chainRef.collection('members').doc(userId);
    final memberDoc = await memberRef.get();

    if (!memberDoc.exists) {
      throw 'You are not a member of this chain.';
    }

    // Remove member and decrement count in a transaction
    // We update the count first, then delete the member document
    // to ensure security rules can validate the member exists
    await _firestore.runTransaction((tx) async {
      final memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) {
        throw 'Member document no longer exists';
      }

      final chainSnap = await tx.get(chainRef);
      if (!chainSnap.exists) {
        throw 'Chain no longer exists';
      }

      // Decrement member count first (while member still exists for security rules)
      final currentCount = (chainSnap.data()?['memberCount'] as int?) ?? 1;
      if (currentCount > 0) {
        tx.update(chainRef, {
          'memberCount': currentCount - 1,
        });
      }

      // Then delete member document
      tx.delete(memberRef);
    });
  }

  /// Delete an entire chain and its direct subcollections (members, messages).
  /// Only the owner is allowed to delete; if requesterId is not the owner,
  /// this will throw.
  Future<void> deleteChain({
    required String chainId,
    required String requesterId,
  }) async {
    final chainRef = _firestore.collection('chains').doc(chainId);
    final snap = await chainRef.get();
    if (!snap.exists) {
      throw 'Chain no longer exists.';
    }

    final data = snap.data() as Map<String, dynamic>? ?? {};
    final ownerId = data['ownerId'] as String? ?? '';
    if (ownerId != requesterId) {
      throw 'Only the chain owner can delete this chain.';
    }

    // Best-effort cleanup helper: delete all docs in a subcollection in batches.
    Future<void> _deleteCollection(
        CollectionReference<Map<String, dynamic>> col) async {
      const batchSize = 50;
      while (true) {
        final snap = await col.limit(batchSize).get();
        if (snap.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    // 1) Delete all members (this is what actually "kicks" people out).
    await _deleteCollection(chainRef.collection('members'));

    // 2) Delete the chain document itself so it no longer appears anywhere.
    //    Do this BEFORE attempting to delete messages so a messages
    //    permission error cannot block removal of the parent chain.
    await chainRef.delete();

    // 3) Best-effort background cleanup of messages. Even if this fails due to
    //    security rules, orphaned messages will no longer be readable once
    //    the parent chain document is gone (given typical security patterns).
    () async {
      try {
        await _deleteCollection(chainRef.collection('messages'));
      } catch (_) {
        // Swallow silently; function's primary responsibility (removing chain)
        // has already succeeded.
      }
    }();
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

  /// Calculate success rate based on check-ins and days since first chain join
  /// Returns a percentage (0.0 - 100.0)
  double _calculateSuccessRate({
    required int checkIns,
    required String? firstChainJoinDate,
    required String today,
  }) {
    // If user hasn't joined any chains yet, success rate is 0
    if (firstChainJoinDate == null || firstChainJoinDate.isEmpty) {
      return 0.0;
    }

    // Parse the first chain join date
    DateTime firstDate;
    try {
      firstDate = DateTime.utc(
        int.parse(firstChainJoinDate.substring(0, 4)),
        int.parse(firstChainJoinDate.substring(5, 7)),
        int.parse(firstChainJoinDate.substring(8, 10)),
      );
    } catch (e) {
      // Invalid date format, return 0
      return 0.0;
    }

    // Parse today's date
    DateTime todayDate;
    try {
      todayDate = DateTime.utc(
        int.parse(today.substring(0, 4)),
        int.parse(today.substring(5, 7)),
        int.parse(today.substring(8, 10)),
      );
    } catch (e) {
      // Invalid date format, return 0
      return 0.0;
    }

    // Calculate total days from first chain join to today (inclusive)
    // Add 1 to include both start and end days
    final totalDays = todayDate.difference(firstDate).inDays + 1;

    // If total days is 0 or negative, return 0
    if (totalDays <= 0) {
      return 0.0;
    }

    // Calculate success rate: (checkIns / totalDays) * 100
    final successRate = (checkIns / totalDays) * 100.0;

    // Clamp to 0-100 range
    return successRate.clamp(0.0, 100.0);
  }

  /// Get the earliest chain join date for a user (for backfilling firstChainJoinDate)
  Future<String?> _getEarliestChainJoinDate(String userId) async {
    try {
      final memberDocs = await _firestore
          .collectionGroup('members')
          .where('userId', isEqualTo: userId)
          .get();

      if (memberDocs.docs.isEmpty) {
        return null;
      }

      DateTime? earliestDate;

      for (final memberDoc in memberDocs.docs) {
        final chainRef = memberDoc.reference.parent.parent;
        if (chainRef == null) continue;

        final chainSnap = await chainRef.get();
        if (!chainSnap.exists) continue;

        final chainData = chainSnap.data() as Map<String, dynamic>? ?? {};
        final startDate = chainData['startDate'] as Timestamp?;
        
        if (startDate != null) {
          final chainStart = startDate.toDate().toUtc();
          final chainStartKey = _dateKeyUtc(chainStart);
          
          if (earliestDate == null) {
            earliestDate = DateTime.utc(
              int.parse(chainStartKey.substring(0, 4)),
              int.parse(chainStartKey.substring(5, 7)),
              int.parse(chainStartKey.substring(8, 10)),
            );
          } else {
            final current = DateTime.utc(
              int.parse(chainStartKey.substring(0, 4)),
              int.parse(chainStartKey.substring(5, 7)),
              int.parse(chainStartKey.substring(8, 10)),
            );
            if (current.isBefore(earliestDate)) {
              earliestDate = current;
            }
          }
        }
      }

      if (earliestDate != null) {
        return _dateKeyUtc(earliestDate);
      }
    } catch (e) {
      print('Error getting earliest chain join date: $e');
    }
    return null;
  }

  /// Update user's global stats after a check-in
  /// Updates checkIns, currentStreak, longestStreak, and lastActiveDate
  Future<void> _updateUserStatsAfterCheckIn(String userId, String today) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    // Backfill firstChainJoinDate if missing (for existing users)
    // Do this BEFORE the transaction to avoid async calls inside transaction
    bool didBackfill = false;
    final userDoc = await userRef.get();
    if (userDoc.exists) {
      final userData = userDoc.data() ?? {};
      final firstChainJoinDate = userData['firstChainJoinDate'] as String?;
      
      if (firstChainJoinDate == null || firstChainJoinDate.isEmpty) {
        final earliestDate = await _getEarliestChainJoinDate(userId);
        if (earliestDate != null) {
          // Backfill the missing firstChainJoinDate
          await userRef.set({'firstChainJoinDate': earliestDate}, SetOptions(merge: true));
          didBackfill = true;
        }
      }
    }
    
    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw 'User profile not found';
      }

      final userData = userSnap.data() ?? {};
      final lastActiveDate = userData['lastActiveDate'] as String?;
      final firstChainJoinDate = userData['firstChainJoinDate'] as String?;
      int currentStreak = (userData['currentStreak'] as int?) ?? 0;
      int longestStreak = (userData['longestStreak'] as int?) ?? 0;
      int checkIns = (userData['checkIns'] as int?) ?? 0;

      // Calculate yesterday's date
      final todayDate = DateTime.utc(
        int.parse(today.substring(0, 4)),
        int.parse(today.substring(5, 7)),
        int.parse(today.substring(8, 10)),
      );
      final yesterdayDate = todayDate.subtract(const Duration(days: 1));
      final yesterday = _dateKeyUtc(yesterdayDate);

      // Update streak based on last active date
      if (lastActiveDate == null) {
        // First check-in ever - streak starts at 1
        currentStreak = 1;
      } else if (lastActiveDate == today) {
        // Already checked in today - don't change stats
        // This shouldn't happen due to the check above, but handle gracefully
        return; // Exit early - stats already updated
      } else if (lastActiveDate == yesterday) {
        // Consecutive day - increment streak
        currentStreak++;
      } else {
        // Not consecutive (missed days) - reset streak to 1 for today
        currentStreak = 1;
      }

      // Update longest streak if current streak exceeds it
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      // Increment check-ins if this is the first check-in today
      if (lastActiveDate != today) {
        checkIns++;
      }

      // Calculate success rate
      // Note: If firstChainJoinDate is null after backfill attempt above,
      // success rate will be 0. It will be recalculated correctly on next check-in
      // once firstChainJoinDate is properly set
      final successRate = _calculateSuccessRate(
        checkIns: checkIns,
        firstChainJoinDate: firstChainJoinDate,
        today: today,
      );

      // Update user document
      tx.update(userRef, {
        'checkIns': checkIns,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActiveDate': today,
        'successRate': successRate,
      });
    });
    
    // If we backfilled firstChainJoinDate, recalculate success rate one more time
    // to ensure accuracy (the transaction might have read before backfill completed)
    if (didBackfill) {
      try {
        final updatedUserDoc = await userRef.get();
        if (updatedUserDoc.exists) {
          final updatedData = updatedUserDoc.data() ?? {};
          final backfilledDate = updatedData['firstChainJoinDate'] as String?;
          final currentCheckIns = (updatedData['checkIns'] as int?) ?? 0;
          
          if (backfilledDate != null && currentCheckIns > 0) {
            final recalculatedRate = _calculateSuccessRate(
              checkIns: currentCheckIns,
              firstChainJoinDate: backfilledDate,
              today: today,
            );
            
            // Update success rate with the recalculated value
            await userRef.update({'successRate': recalculatedRate});
          }
        }
      } catch (e) {
        // Non-critical: if recalculation fails, success rate will update on next check-in
        print('Error recalculating success rate after backfill: $e');
      }
    }
  }
}