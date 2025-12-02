import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/shop_service.dart';
import '../services/currency_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> with SingleTickerProviderStateMixin {
  final _shopService = ShopService();
  final _currencyService = CurrencyService();
  final _authService = AuthService();
  final _userService = UserService();

  late TabController _tabController;
  int _coins = 0;
  bool _isPremium = false;
  List<String> _purchasedThemes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Ensure coins field exists for existing users (migration)
      await _currencyService.ensureCoinsField(user.uid);
      
      final userDoc = await _userService.getUserProfile(user.uid);
      final data = userDoc.data() ?? {};
      
      final isPremium = await _shopService.isPremiumActive(user.uid);
      
      setState(() {
        _coins = (data['coins'] as int?) ?? 0;
        _isPremium = isPremium;
        _purchasedThemes = List<String>.from(data['purchasedThemes'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    await _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shop')),
        body: const Center(child: Text('Please sign in to access the shop')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Themes', icon: Icon(Icons.palette)),
            Tab(text: 'Premium', icon: Icon(Icons.stars)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Currency display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.3),
                    border: Border(
                      bottom: BorderSide(color: cs.outline.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monetization_on, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        '$_coins coins',
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildThemesTab(),
                      _buildPremiumTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildThemesTab() {
    final allThemes = _shopService.getAllThemes();
    final themeColors = {
      'Ocean': [const Color(0xFF7B61FF), const Color(0xFF4C8DFF)],
      'Forest': [const Color(0xFF14C38E), const Color(0xFF3CCF4E)],
      'Sunset': [const Color(0xFFFF6EC7), const Color(0xFFFF9A9E)],
      'Energy': [const Color(0xFFFF5A5F), const Color(0xFFFFC371)],
      'Galaxy': [const Color(0xFF6B46C1), const Color(0xFF9333EA)],
      'Aurora': [const Color(0xFF10B981), const Color(0xFF06B6D4)],
      'Neon': [const Color(0xFFEC4899), const Color(0xFFF59E0B)],
      'Minimal': [const Color(0xFF6B7280), const Color(0xFF9CA3AF)],
    };

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: allThemes.length,
        itemBuilder: (context, index) {
          final theme = allThemes[index];
          final name = theme['name'] as String;
          final cost = theme['cost'] as int;
          final type = theme['type'] as String;
          final isOwned = _purchasedThemes.contains(name) || type == 'free';
          final colors = themeColors[name] ?? [Colors.grey, Colors.grey.shade700];

          return _ThemeCard(
            name: name,
            colors: colors,
            cost: cost,
            isOwned: isOwned,
            canAfford: _coins >= cost,
            onTap: isOwned
                ? null
                : () => _purchaseTheme(name, cost),
          );
        },
      ),
    );
  }

  Widget _buildPremiumTab() {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final user = _authService.currentUser;

    if (user == null) return const SizedBox();

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isPremium) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Active',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'Enjoy unlimited chains and all premium features!',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          _PremiumCard(
            title: 'Lifetime Premium',
            description: 'Unlock all features forever',
            cost: ShopService.PREMIUM_LIFETIME_COINS,
            isOwned: _isPremium,
            canAfford: _coins >= ShopService.PREMIUM_LIFETIME_COINS,
            icon: Icons.all_inclusive,
            color: Colors.purple,
            onTap: _isPremium
                ? null
                : () => _purchasePremium('lifetime', ShopService.PREMIUM_LIFETIME_COINS),
          ),
          const SizedBox(height: 16),
          _PremiumCard(
            title: 'Monthly Premium',
            description: 'Full access for 30 days',
            cost: ShopService.PREMIUM_MONTHLY_COINS,
            isOwned: false,
            canAfford: _coins >= ShopService.PREMIUM_MONTHLY_COINS,
            icon: Icons.calendar_month,
            color: Colors.blue,
            onTap: () => _purchasePremium('monthly', ShopService.PREMIUM_MONTHLY_COINS),
          ),
          const SizedBox(height: 16),
          _PremiumCard(
            title: 'Yearly Premium',
            description: 'Full access for 365 days',
            cost: ShopService.PREMIUM_YEARLY_COINS,
            isOwned: false,
            canAfford: _coins >= ShopService.PREMIUM_YEARLY_COINS,
            icon: Icons.calendar_today,
            color: Colors.orange,
            onTap: () => _purchasePremium('yearly', ShopService.PREMIUM_YEARLY_COINS),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseTheme(String themeName, int cost) async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (_coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough coins! You need $cost coins.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase $themeName Theme?'),
        content: Text('This will cost $cost coins. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Purchase'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _shopService.purchaseTheme(user.uid, themeName);
      await _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$themeName theme purchased successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
  }

  Future<void> _purchasePremium(String type, int cost) async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (_coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough coins! You need $cost coins.')),
      );
      return;
    }

    final typeName = type == 'lifetime'
        ? 'Lifetime Premium'
        : type == 'monthly'
            ? 'Monthly Premium'
            : 'Yearly Premium';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase $typeName?'),
        content: Text('This will cost $cost coins. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Purchase'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _shopService.purchasePremium(user.uid, type);
      await _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$typeName activated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
  }
}

class _ThemeCard extends StatelessWidget {
  final String name;
  final List<Color> colors;
  final int cost;
  final bool isOwned;
  final bool canAfford;
  final VoidCallback? onTap;

  const _ThemeCard({
    required this.name,
    required this.colors,
    required this.cost,
    required this.isOwned,
    required this.canAfford,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!isOwned && cost > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$cost coins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isOwned)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              ),
            if (!isOwned && !canAfford)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final String title;
  final String description;
  final int cost;
  final bool isOwned;
  final bool canAfford;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _PremiumCard({
    required this.title,
    required this.description,
    required this.cost,
    required this.isOwned,
    required this.canAfford,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: isOwned ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOwned ? Colors.green : color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.monetization_on, size: 16, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        '$cost coins',
                        style: text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isOwned)
              const Icon(Icons.check_circle, color: Colors.green, size: 32)
            else if (!canAfford)
              const Icon(Icons.lock, color: Colors.grey, size: 32),
          ],
        ),
      ),
    );
  }
}

