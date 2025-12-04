import 'package:cloud_firestore/cloud_firestore.dart';
import 'currency_service.dart';

class ShopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CurrencyService _currencyService = CurrencyService();

  // Free themes available to all users
  static const List<String> FREE_THEMES = ['Ocean', 'Forest', 'Sunset', 'Energy'];

  // Premium theme definitions with costs
  static const Map<String, int> PREMIUM_THEMES = {
    'Galaxy': 200,
    'Aurora': 200,
    'Neon': 200,
    'Minimal': 150,
  };

  // Premium subscription costs
  static const int PREMIUM_LIFETIME_COINS = 999;
  static const int PREMIUM_MONTHLY_COINS = 199;
  static const int PREMIUM_YEARLY_COINS = 999;

  /// Get all available themes for a user (free + purchased)
  Future<List<String>> getAvailableThemes(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data() ?? {};
    final purchased = List<String>.from(data['purchasedThemes'] ?? []);

    // Free themes are always available
    return [...FREE_THEMES, ...purchased];
  }

  /// Check if user has purchased a specific theme
  Future<bool> hasPurchasedTheme(String userId, String themeName) async {
    // Free themes are always available
    if (FREE_THEMES.contains(themeName)) return true;

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data() ?? {};
    final purchased = List<String>.from(data['purchasedThemes'] ?? []);
    return purchased.contains(themeName);
  }

  /// Get theme cost
  int? getThemeCost(String themeName) {
    return PREMIUM_THEMES[themeName];
  }

  /// Purchase a theme with coins
  Future<void> purchaseTheme(String userId, String themeName) async {
    // Check if already owned
    if (await hasPurchasedTheme(userId, themeName)) {
      throw 'You already own this theme!';
    }

    // Get cost
    final cost = getThemeCost(themeName);
    if (cost == null) {
      throw 'Invalid theme name';
    }

    // Deduct coins
    await _currencyService.deductCoins(userId, cost);

    // Add to purchased themes
    await _firestore.collection('users').doc(userId).update({
      'purchasedThemes': FieldValue.arrayUnion([themeName]),
    });
  }

  /// Check if user has active premium subscription
  Future<bool> isPremiumActive(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data() ?? {};
    final isPremium = data['isPremium'] as bool? ?? false;

    if (!isPremium) return false;

    // Check if lifetime premium
    final premiumType = data['premiumType'] as String?;
    if (premiumType == 'lifetime') return true;

    // Check expiration for subscription-based premium
    final expiresAt = data['premiumExpiresAt'] as Timestamp?;
    if (expiresAt == null) return true; // No expiration set (legacy)

    final now = DateTime.now();
    final expirationDate = expiresAt.toDate();

    if (expirationDate.isBefore(now)) {
      // Premium has expired, update status
      await _firestore.collection('users').doc(userId).update({
        'isPremium': false,
      });
      return false;
    }

    return true;
  }

  /// Purchase premium subscription
  Future<void> purchasePremium(
    String userId,
    String type, {
    int? customCost,
  }) async {
    // Validate type
    if (!['lifetime', 'monthly', 'yearly'].contains(type)) {
      throw 'Invalid premium type';
    }

    // Determine cost
    int cost;
    if (customCost != null) {
      cost = customCost;
    } else {
      switch (type) {
        case 'lifetime':
          cost = PREMIUM_LIFETIME_COINS;
          break;
        case 'monthly':
          cost = PREMIUM_MONTHLY_COINS;
          break;
        case 'yearly':
          cost = PREMIUM_YEARLY_COINS;
          break;
        default:
          throw 'Invalid premium type';
      }
    }

    // Check if already premium (and not expired)
    if (await isPremiumActive(userId)) {
      throw 'You already have an active premium subscription!';
    }

    // Deduct coins
    await _currencyService.deductCoins(userId, cost);

    // Calculate expiration date
    Timestamp? expiresAt;
    if (type == 'lifetime') {
      expiresAt = null; // Lifetime never expires
    } else if (type == 'monthly') {
      expiresAt = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
    } else if (type == 'yearly') {
      expiresAt = Timestamp.fromDate(DateTime.now().add(const Duration(days: 365)));
    }

    // Update user premium status
    await _firestore.collection('users').doc(userId).update({
      'isPremium': true,
      'premiumType': type,
      'premiumExpiresAt': expiresAt,
    });
  }

  /// Get all shop items with their details
  Map<String, dynamic> getShopItems() {
    return {
      'themes': {
        'free': FREE_THEMES.map((theme) => {
              'name': theme,
              'cost': 0,
              'type': 'free',
            }).toList(),
        'premium': PREMIUM_THEMES.entries.map((entry) {
              return {
                'name': entry.key,
                'cost': entry.value,
                'type': 'premium',
              };
            }).toList(),
      },
      'premium': {
        'lifetime': {
          'type': 'lifetime',
          'costCoins': PREMIUM_LIFETIME_COINS,
          'description': 'Unlimited access forever',
        },
        'monthly': {
          'type': 'monthly',
          'costCoins': PREMIUM_MONTHLY_COINS,
          'description': 'Full access for 30 days',
        },
        'yearly': {
          'type': 'yearly',
          'costCoins': PREMIUM_YEARLY_COINS,
          'description': 'Full access for 365 days',
        },
      },
    };
  }

  /// Get all themes (free + premium) for display in shop
  List<Map<String, dynamic>> getAllThemes() {
    final allThemes = <Map<String, dynamic>>[];

    // Add free themes
    for (final theme in FREE_THEMES) {
      allThemes.add({
        'name': theme,
        'cost': 0,
        'type': 'free',
      });
    }

    // Add premium themes
    for (final entry in PREMIUM_THEMES.entries) {
      allThemes.add({
        'name': entry.key,
        'cost': entry.value,
        'type': 'premium',
      });
    }

    return allThemes;
  }
}


