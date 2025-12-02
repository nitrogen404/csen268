import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart';
import '../services/chain_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/friend_service.dart';
import '../services/shop_service.dart';
import 'chain_detail_page.dart';
import 'shop_page.dart';

class CreateChainStep2 extends StatefulWidget {
  final String habitName;
  final String frequency;
  final DateTime? startDate;
  final int durationDays;

  const CreateChainStep2({
    super.key,
    required this.habitName,
    required this.frequency,
    required this.startDate,
    required this.durationDays,
  });

  @override
  State<CreateChainStep2> createState() => _CreateChainStep2State();
}

class _CreateChainStep2State extends State<CreateChainStep2>
    with SingleTickerProviderStateMixin {
  String selectedTheme = 'Ocean';

  final ChainService _chainService = ChainService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final FriendService _friendService = FriendService();
  final ShopService _shopService = ShopService();

  // Friends selected to receive chain invites after creation.
  final Set<String> _selectedFriendIds = {};

  bool _isCreating = false;
  List<String> _availableThemes = [];
  bool _loadingThemes = true;

  late final AnimationController _inviteSpinnerController;

  @override
  void initState() {
    super.initState();
    _inviteSpinnerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadAvailableThemes();
  }

  Future<void> _loadAvailableThemes() async {
    final user = _authService.currentUser;
    if (user == null) {
      setState(() {
        _availableThemes = ShopService.FREE_THEMES;
        _loadingThemes = false;
      });
      return;
    }

    try {
      final available = await _shopService.getAvailableThemes(user.uid);
      setState(() {
        _availableThemes = available;
        // Ensure selected theme is available, otherwise default to first available
        if (!_availableThemes.contains(selectedTheme) && _availableThemes.isNotEmpty) {
          selectedTheme = _availableThemes.first;
        }
        _loadingThemes = false;
      });
    } catch (e) {
      setState(() {
        _availableThemes = ShopService.FREE_THEMES;
        _loadingThemes = false;
      });
    }
  }

  @override
  void dispose() {
    _inviteSpinnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              navIndex.value = 0;
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Create New Chain",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              "Step 2 of 2",
              style: text.labelMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: 1.0,
            backgroundColor: cs.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(cs.primary),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const SizedBox(height: 12),

            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.palette_outlined, size: 42, color: cs.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  "Personalize & Share",
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Customize your chain and invite friends",
                  style: text.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),

            const SizedBox(height: 28),

            Text(
              "Choose Theme",
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            _loadingThemes
                ? const Center(child: CircularProgressIndicator())
                : Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: _getAllThemes().map((themeData) {
                      return _themeOption(
                        themeData['name'] as String,
                        themeData['colors'] as List<Color>,
                        themeData['available'] as bool,
                        themeData['cost'] as int?,
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 28),

            Text(
              "Invite Friends (Optional)",
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            if (user != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _friendService.streamFriends(user.uid),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Text(
                      'No friends yet. You can add friends from chain members.',
                      style: text.bodySmall?.copyWith(
                        color: cs.onBackground.withOpacity(0.6),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...docs.map((d) {
                        final data = d.data();
                        final friendId =
                            (data['userId'] as String?) ?? d.id;
                        final name =
                            (data['displayName'] as String?) ?? 'Friend';
                        final email =
                            (data['email'] as String?) ?? '';

                        final selected =
                            _selectedFriendIds.contains(friendId);

                        return CheckboxListTile(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedFriendIds.add(friendId);
                              } else {
                                _selectedFriendIds.remove(friendId);
                              }
                            });
                          },
                          title: Text(name),
                          subtitle: Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                  );
                },
              )
            else
              Text(
                'Sign in to invite friends to this chain.',
                style: text.bodySmall?.copyWith(
                  color: cs.onBackground.withOpacity(0.6),
                ),
              ),

            const SizedBox(height: 24),

            if (user != null && _selectedFriendIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Invited Friends",
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _friendService.streamFriends(user!.uid),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        final invitedDocs = docs.where((d) {
                          final fid =
                              (d.data()['userId'] as String?) ?? d.id;
                          return _selectedFriendIds.contains(fid);
                        }).toList();

                        if (invitedDocs.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          children: invitedDocs.map((d) {
                            final data = d.data();
                            final name =
                                (data['displayName'] as String?) ??
                                    'Friend';
                            final email =
                                (data['email'] as String?) ?? '';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor:
                                    cs.primary.withOpacity(0.1),
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(color: cs.primary),
                                ),
                              ),
                              title: Text(name),
                              subtitle: Text(
                                'Pending • $email',
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: RotationTransition(
                                turns: _inviteSpinnerController,
                                child: Icon(
                                  Icons.hourglass_empty_rounded,
                                  color: cs.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _isCreating ? null : _createChain,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Create Chain",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get all themes with their colors and availability
  List<Map<String, dynamic>> _getAllThemes() {
    final allThemes = <Map<String, dynamic>>[];

    // Define theme colors
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

    // Get all themes from shop service
    final allShopThemes = _shopService.getAllThemes();

    for (final themeData in allShopThemes) {
      final name = themeData['name'] as String;
      final cost = themeData['cost'] as int;
      final type = themeData['type'] as String;
      final isAvailable = _availableThemes.contains(name);
      final colors = themeColors[name] ?? [Colors.grey, Colors.grey.shade700];

      allThemes.add({
        'name': name,
        'colors': colors,
        'available': isAvailable,
        'cost': cost,
        'type': type,
      });
    }

    return allThemes;
  }

  Widget _themeOption(String name, List<Color> colors, bool isAvailable, int? cost) {
    final isSelected = selectedTheme == name;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isAvailable
          ? () => setState(() => selectedTheme = name)
          : () {
              // Navigate to shop to purchase theme
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopPage()),
              );
            },
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.6,
        child: Container(
          width: (MediaQuery.of(context).size.width / 2) - 28,
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: Colors.white, width: 3)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected && isAvailable)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.green,
                      size: 16,
                    ),
                  ),
                ),
              if (!isAvailable)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 24,
                        ),
                        if (cost != null && cost > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '$cost coins',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createChain() async {
    final user = _authService.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create a chain')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final chain = await _chainService.createChain(
        ownerId: user.uid,
        ownerEmail: user.email ?? '',
        title: widget.habitName,
        frequency: widget.frequency,
        startDate: widget.startDate,
        durationDays: widget.durationDays,
        theme: selectedTheme,
      );

      if (!mounted) return;

      // Owner is automatically subscribed to this chain's notifications.
      try {
        final topic = 'chain_${chain.id}';
        await _notificationService.subscribeToTopic(topic);
        await _notificationService.showSubscriptionNotification(chain.title);
      } catch (e) {
        // Subscription failure should not block chain creation flow.
        debugPrint('Failed to subscribe creator to chain notifications: $e');
      }

      // Send chain invites to selected friends.
      if (_selectedFriendIds.isNotEmpty) {
        for (final friendId in _selectedFriendIds) {
          try {
            await _friendService.sendChainInvite(
              toUserId: friendId,
              chainId: chain.id,
              chainTitle: chain.title,
              chainCode: chain.code,
              inviterId: user.uid,
              inviterEmail: user.email ?? '',
              inviterName: widget.habitName,
            );
          } catch (e) {
            debugPrint('Failed to invite friend $friendId: $e');
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chain created! Share your code: ${chain.code}')),
      );

      navIndex.value = 0;

      Navigator.of(context).popUntil((r) => r.isFirst);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChainDetailPage(
            chainId: chain.id,
            chainTitle: chain.title,
            members: chain.members,
            progress: chain.progress,
            code: chain.code,
            theme: chain.theme,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString();
      
      // Check if error is about chain limit
      if (errorMessage.contains('Free users can only have')) {
        _showUpgradeDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create chain: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
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
}
