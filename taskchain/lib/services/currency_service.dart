import 'package:cloud_firestore/cloud_firestore.dart';

class CurrencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Coin earning constants
  static const int COINS_PER_CHECKIN = 5;
  static const int COINS_PER_STREAK_MILESTONE = 10; // Every 7 days
  static const int STREAK_MILESTONE_DAYS = 7;
  static const int COINS_FOR_CHAIN_COMPLETION = 50;

  /// Get current coin balance for a user
  Future<int> getCoins(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data() ?? {};
    return (data['coins'] as int?) ?? 0;
  }

  /// Ensure coins field exists for a user (initialize to 0 if missing)
  /// This is public so it can be called directly to initialize coins for existing users
  Future<void> ensureCoinsField(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return;
    
    final data = userDoc.data() ?? {};
    if (!data.containsKey('coins')) {
      await _firestore.collection('users').doc(userId).set({
        'coins': 0,
      }, SetOptions(merge: true));
    }
  }

  /// Private helper that calls the public method
  Future<void> _ensureCoinsField(String userId) async {
    await ensureCoinsField(userId);
  }

  /// Add coins to user's balance
  Future<void> addCoins(String userId, int amount, String reason) async {
    if (amount <= 0) return;

    // Ensure coins field exists before incrementing
    await _ensureCoinsField(userId);

    await _firestore.collection('users').doc(userId).update({
      'coins': FieldValue.increment(amount),
    });

    // Optional: Log coin transaction for history (non-blocking)
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('coinTransactions')
          .add({
        'amount': amount,
        'type': 'earned',
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log transaction failure but don't block the coin addition
      print('Failed to log coin transaction: $e');
    }
  }

  /// Deduct coins from user's balance
  Future<void> deductCoins(String userId, int amount) async {
    if (amount <= 0) return;

    // Ensure coins field exists
    await _ensureCoinsField(userId);

    final currentCoins = await getCoins(userId);
    if (currentCoins < amount) {
      throw 'Insufficient coins. You need $amount coins but only have $currentCoins.';
    }

    await _firestore.collection('users').doc(userId).update({
      'coins': FieldValue.increment(-amount),
    });

    // Optional: Log coin transaction for history (non-blocking)
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('coinTransactions')
          .add({
        'amount': -amount,
        'type': 'spent',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log transaction failure but don't block the coin deduction
      print('Failed to log coin transaction: $e');
    }
  }

  /// Award coins for daily check-in
  Future<void> earnCoinsFromCheckIn(String userId) async {
    await addCoins(userId, COINS_PER_CHECKIN, 'Daily check-in');
  }

  /// Award bonus coins for streak milestones
  /// Awards coins every 7 days (7, 14, 21, etc.)
  Future<void> earnCoinsFromStreak(String userId, int streakDays) async {
    if (streakDays <= 0) return;

    // Calculate how many milestones have been reached
    final milestonesReached = streakDays ~/ STREAK_MILESTONE_DAYS;
    if (milestonesReached <= 0) return;

    // Get last milestone recorded
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data() ?? {};
    final lastMilestoneRecorded =
        (data['lastStreakMilestone'] as int?) ?? 0;

    // Award coins for new milestones
    final newMilestones = milestonesReached - lastMilestoneRecorded;
    if (newMilestones > 0) {
      final coinsToAward = newMilestones * COINS_PER_STREAK_MILESTONE;
      await addCoins(userId, coinsToAward,
          'Streak milestone (${milestonesReached * STREAK_MILESTONE_DAYS} days)');

      // Update last milestone recorded
      await _firestore.collection('users').doc(userId).update({
        'lastStreakMilestone': milestonesReached,
      });
    }
  }

  /// Award coins when a chain is completed
  Future<void> earnCoinsFromChainCompletion(String userId) async {
    await addCoins(userId, COINS_FOR_CHAIN_COMPLETION, 'Chain completion');
  }
}

