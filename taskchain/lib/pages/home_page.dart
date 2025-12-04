import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/stat_tile.dart';
import '../widgets/chain_card_with_badge.dart';
import '../widgets/animated_list_item.dart';
import '../services/auth_service.dart';
import '../services/chain_service.dart';
import '../services/notification_service.dart';
import '../services/shop_service.dart';
import '../models/chain.dart';
import '../models/profile.dart';
import 'settings_page.dart';
import 'chain_detail_page.dart';
import 'shop_page.dart';
import 'chatbot_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _chainService = ChainService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _codeController = TextEditingController();
  bool _isJoining = false;
  String? _joinError;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinChain() async {
    final user = _authService.currentUser;

    if (user == null) {
      setState(() {
        _joinError = 'Please sign in to join a chain.';
      });
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _joinError = 'Please enter a chain code.';
      });
      return;
    }

    setState(() {
      _isJoining = true;
      _joinError = null;
    });

    try {
      final joined = await _chainService.joinChainByCode(
        userId: user.uid,
        userEmail: user.email ?? '',
        code: code,
      );

      if (!mounted) return;

      _codeController.clear();

      // If this is a brand new membership, subscribe to chain notifications
      // and show a system notification indicating subscription.
      if (joined) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('chains')
              .where('code', isEqualTo: code)
              .limit(1)
              .get();

          if (snap.docs.isNotEmpty) {
            final doc = snap.docs.first;
            final data = doc.data();
            final chainTitle = (data['title'] as String?) ?? 'Chain';
            final chainId = doc.id;

            final topic = 'chain_$chainId';
            await _notificationService.subscribeToTopic(topic);
            await _notificationService.showSubscriptionNotification(chainTitle);
          }
        } catch (e) {
          // If subscription fails, we still consider the join successful;
          // log the error but don't surface it as a blocking failure.
          debugPrint('Failed to subscribe to chain notifications: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            joined
                ? 'Joined chain successfully'
                : 'You are already a member of this chain.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString();
      if (errorMessage.contains('Free users can only have')) {
        _showUpgradeDialog();
      } else {
        setState(() {
          _joinError = errorMessage;
        });
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.stars, color: Color(0xFF7B61FF)),
            SizedBox(width: 8),
            Text('Chain Limit Reached'),
          ],
        ),
        content: const Text(
          'Free users can only have 2 active chains. Upgrade to Premium for unlimited chains and more features!',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopPage()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7B61FF),
            ),
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanAndJoin() async {
    if (_isJoining) return;

    final user = _authService.currentUser;
    if (user == null) {
      setState(() {
        _joinError = 'Please sign in to join a chain.';
      });
      return;
    }

    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _QrScanPage(),
      ),
    );

    if (code == null || code.trim().isEmpty) {
      return;
    }

    _codeController.text = code.trim();
    await _joinChain();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final currentUser = _authService.currentUser;

    return CustomScrollView(
      slivers: [
        // Header Section (dynamic: depends on chain count and stats)
        SliverToBoxAdapter(
          child: StreamBuilder<List<Chain>>(
            stream: currentUser != null
                ? _chainService.streamJoinedChains(currentUser.uid)
                : const Stream.empty(),
            builder: (context, snapshot) {
              final isWaiting = snapshot.connectionState == ConnectionState.waiting;
              final chains = snapshot.data ?? [];
              final hasChains = chains.isNotEmpty;

              // Derive simple, user-friendly stats from chains.
              int totalDays = 0;
              int friendsActive = 0;
              int avgProgressPercent = 0;

              if (hasChains) {
                for (final c in chains) {
                  totalDays += c.totalDaysCompleted;
                  // All members except the current user (approximation)
                  friendsActive += (c.memberCount - 1).clamp(0, c.memberCount);
                  avgProgressPercent += (c.progress * 100).round();
                }
                avgProgressPercent = (avgProgressPercent / chains.length).round();
              }

              return Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7B61FF),
                      const Color(0xFFFF6EC7)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row with settings button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    hasChains ? "Welcome back" : "Welcome to TaskChain",
                                    style: text.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        transitionDuration:
                                            const Duration(milliseconds: 600),
                                        pageBuilder: (_, animation, secondary) =>
                                            const SettingsPage(),
                                        transitionsBuilder: (_, animation, secondary, child) {
                                          return SharedAxisTransition(
                                            animation: animation,
                                            secondaryAnimation: secondary,
                                            transitionType: SharedAxisTransitionType.horizontal,
                                            child: child,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.settings_outlined),
                                  color: Colors.white,
                                  iconSize: 28,
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(
                              hasChains
                                  ? "Keep those chains alive!"
                                  : isWaiting
                                      ? "Loading your chains..."
                                      : "Create your first habit chain to get started.",
                              style: text.bodyLarge?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Dynamic stats from Firestore-backed chain data.
                    if (hasChains)
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              icon: Icons.local_fire_department,
                              value: '$totalDays',
                              label: 'Total Days',
                              iconColor: AppColors.statLongestStreak, // Orange/yellow for fire
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatTile(
                              icon: Icons.group,
                              value: '$friendsActive',
                              label: 'Friends Active',
                              iconColor: AppColors.statTotalChains, // Blue for people
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatTile(
                              icon: Icons.show_chart,
                              value: '$avgProgressPercent%',
                              label: 'Avg Progress',
                              iconColor: AppColors.statSuccessRate, // Green for chart
                            ),
                          ),
                        ],
                      ),
                    if (!hasChains && isWaiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        // Your Chains Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your Chains",
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText: 'Enter chain code',
                          filled: true,
                          fillColor: cs.surfaceVariant.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isJoining ? null : _joinChain,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(90, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isJoining
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Join'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _scanAndJoin,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Scan chain QR',
                    ),
                  ],
                ),

                if (_joinError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _joinError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Joined Chains List
        if (currentUser != null)
          SliverToBoxAdapter(
            child: StreamBuilder<List<Chain>>(
              stream: _chainService.streamJoinedChains(currentUser.uid),
              builder: (context, snapshot) {
                final isWaiting = snapshot.connectionState == ConnectionState.waiting;
                final chains = snapshot.data ?? [];

                if (chains.isEmpty) {
                  if (isWaiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'You haven\'t joined any chains yet.\nEnter a code above to join.',
                        style: text.bodyMedium,
                      ),
                    );
                  }
                }

                return Column(
                  children: [
                    const SizedBox(height: 8),
                    for (var i = 0; i < chains.length; i++)
                      AnimatedListItem(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ChainCardWithBadge(
                            chainId: chains[i].id,
                            progress: chains[i].progress,
                            title: chains[i].title,
                            days: chains[i].days,
                            members: chains[i].members,
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  transitionDuration:
                                      const Duration(milliseconds: 600),
                                  pageBuilder: (_, animation, secondary) =>
                                      ChainDetailPage(
                                    chainId: chains[i].id,
                                    chainTitle: chains[i].title,
                                    members: chains[i].members,
                                    progress: chains[i].progress,
                                    code: chains[i].code,
                                    theme: chains[i].theme,
                                  ),
                                  transitionsBuilder: (_, animation, secondary, child) {
                                    return SharedAxisTransition(
                                      animation: animation,
                                      secondaryAnimation: secondary,
                                      transitionType:
                                          SharedAxisTransitionType.horizontal,
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

        // Shop and AI Coach Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: _QuickAccessCard(
                    title: 'Shop',
                    subtitle: 'Themes & Premium',
                    icon: Icons.shopping_bag,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ShopPage()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _QuickAccessCard(
                    title: 'AI Coach',
                    subtitle: 'Get personalized help',
                    icon: Icons.smart_toy,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatbotPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: (text.titleMedium ?? const TextStyle(fontSize: 16)).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: (text.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
                color: cs.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  bool _isProcessed = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessed) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    _isProcessed = true;
    Navigator.of(context).pop(raw.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Chain QR'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Point the camera at a TaskChain QR code',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
