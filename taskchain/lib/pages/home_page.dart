import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../widgets/stat_tile.dart';
import '../widgets/chain_card_with_badge.dart';
import '../widgets/animated_list_item.dart';
import '../services/auth_service.dart';
import '../services/chain_service.dart';
import '../models/chain.dart';
import 'settings_page.dart';
import 'chain_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _chainService = ChainService();
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
      if (mounted) {
        _controller.forward();
      }
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
      await _chainService.joinChainByCode(
        userId: user.uid,
        userEmail: user.email ?? '',
        code: code,
      );
      if (!mounted) return;
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined chain successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _joinError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final currentUser = _authService.currentUser;

    return CustomScrollView(
      slivers: [
        // Gradient header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF7B61FF), const Color(0xFFFF6EC7)],
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Welcome back",
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
                                    transitionDuration: const Duration(milliseconds: 600),
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        const SettingsPage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return SharedAxisTransition(
                                        animation: animation,
                                        secondaryAnimation: secondaryAnimation,
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
                          "Keep those chains alive!",
                          style: text.bodyLarge?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(
                      child: StatTile(
                        icon: Icons.local_fire_department,
                        value: "42",
                        label: "Total Days",
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.group,
                        value: "9",
                        label: "Friends Active",
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.show_chart,
                        value: "78%",
                        label: "Avg Progress",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Your Chains header + join form
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Your Chains",
                      style:
                          text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (currentUser == null)
                      const Text(
                        'Sign in to join',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Join a chain input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText: 'Enter chain code',
                          hintText: 'e.g. ABC123',
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

        // Chain cards (joined chains)
        if (currentUser == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Sign in to see the chains you have joined.',
                style: text.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: StreamBuilder<List<Chain>>(
              stream: _chainService.streamJoinedChains(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Failed to load your chains.',
                      style: text.bodyMedium?.copyWith(color: Colors.redAccent),
                    ),
                  );
                }

                final chains = snapshot.data ?? [];

                if (chains.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'You haven\'t joined any chains yet.\nEnter a code above to join a chain.',
                      style: text.bodyMedium,
                    ),
                  );
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
                                  transitionDuration: const Duration(milliseconds: 600),
                                  pageBuilder: (context, animation, secondaryAnimation) =>
                                      ChainDetailPage(
                                    chainId: chains[i].id,
                                    chainTitle: chains[i].title,
                                    members: chains[i].members,
                                    progress: chains[i].progress,
                                    code: chains[i].code,
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return SharedAxisTransition(
                                      animation: animation,
                                      secondaryAnimation: secondaryAnimation,
                                      transitionType: SharedAxisTransitionType.horizontal,
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

        // Recent Achievements header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              "Recent Achievements",
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),

        // Achievements row
        SliverToBoxAdapter(
          child: SizedBox(
            height: 140,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: const [
                _Achieve(
                  icon: Icons.emoji_events,
                  title: "Streak x10",
                  subtitle: "Nice consistency!",
                ),
                _Achieve(
                  icon: Icons.business_rounded,
                  title: "Goal Hit",
                  subtitle: "3 goals this week",
                ),
                _Achieve(
                  icon: Icons.shield_moon,
                  title: "Night Owl",
                  subtitle: "Tasks after 10pm",
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _Achieve extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Achieve({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const Spacer(),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(subtitle),
        ],
      ),
    );
  }
}
