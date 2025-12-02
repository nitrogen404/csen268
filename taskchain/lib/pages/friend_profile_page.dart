import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/chain_service.dart';
import '../models/chain.dart';
import '../models/profile.dart';
import '../widgets/stat_tile.dart';
import 'full_screen_image_page.dart';

class FriendProfilePage extends StatelessWidget {
  final String userId;
  final String? fallbackEmail;

  const FriendProfilePage({
    super.key,
    required this.userId,
    this.fallbackEmail,
  });

  @override
  Widget build(BuildContext context) {
    final userService = UserService();
    final auth = AuthService();
    final currentUser = auth.currentUser;
    final chainService = ChainService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userService.streamUserProfile(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final displayName =
              data['displayName'] as String? ?? fallbackEmail ?? 'TaskChain User';
          final email = data['email'] as String? ?? fallbackEmail ?? '';
          final bio = data['bio'] as String? ?? '';
          final profilePictureUrl =
              data['profilePictureUrl'] as String?;
          final createdAt = data['createdAt'] as Timestamp?;

          String memberSince = '';
          if (createdAt != null) {
            final d = createdAt.toDate();
            memberSince =
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          }

          // Stats / achievements
          final longestStreak = (data['longestStreak'] ?? 0).toString();
          final checkIns = (data['checkIns'] ?? 0).toString();
          final rawSuccess = data['successRate'];
          String successRate;
          if (rawSuccess is num) {
            successRate = '${rawSuccess.toStringAsFixed(0)}%';
          } else {
            successRate = '0%';
          }
          final currentStreak = (data['currentStreak'] ?? 0).toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FriendHeader(
                  displayName: displayName,
                  email: email,
                  bio: bio,
                  memberSince: memberSince,
                  profilePictureUrl: profilePictureUrl,
                ),
                const SizedBox(height: 16),
                StreamBuilder<int>(
                  stream: chainService.streamJoinedChainCount(userId),
                  builder: (context, countSnap) {
                    final totalChains = countSnap.data ?? 0;
                    return _FriendAchievementsSection(
                      currentStreak: int.tryParse(currentStreak) ?? 0,
                      longestStreak: int.tryParse(longestStreak) ?? 0,
                      checkIns: int.tryParse(checkIns) ?? 0,
                      totalChains: totalChains,
                    );
                  },
                ),
                const SizedBox(height: 16),
                _FriendStatsSection(
                  stats: [
                    ProfileStat(
                      currentStreak,
                      'Current Streak',
                      Icons.local_fire_department,
                      AppColors.statLongestStreak,
                    ),
                    ProfileStat(
                      longestStreak,
                      'Longest Streak',
                      Icons.emoji_events_outlined,
                      AppColors.statLongestStreak,
                    ),
                    ProfileStat(
                      checkIns,
                      'Check-ins',
                      Icons.calendar_today,
                      AppColors.statCheckIns,
                    ),
                    ProfileStat(
                      successRate,
                      'Success Rate',
                      Icons.trending_up,
                      AppColors.statSuccessRate,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (currentUser != null)
                  _CommonChainsSection(
                    currentUserId: currentUser.uid,
                    friendUserId: userId,
                    chainService: chainService,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FriendAchievementsSection extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final int checkIns;
  final int totalChains;

  const _FriendAchievementsSection({
    required this.currentStreak,
    required this.longestStreak,
    required this.checkIns,
    required this.totalChains,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final achievements = [
      _FriendAchievement(
        title: '10-day longest streak',
        badgeAsset: 'assets/images/10_streak.png',
        achieved: longestStreak >= 10,
      ),
      _FriendAchievement(
        title: '20-day longest streak',
        badgeAsset: 'assets/images/20_streak.png',
        achieved: longestStreak >= 20,
      ),
      _FriendAchievement(
        title: '50-day longest streak',
        badgeAsset: 'assets/images/50_streak.png',
        achieved: longestStreak >= 50,
      ),
      _FriendAchievement(
        title: '100-day longest streak',
        badgeAsset: 'assets/images/100_streak.png',
        achieved: longestStreak >= 100,
      ),
      _FriendAchievement(
        title: '5-day current streak',
        badgeAsset: 'assets/images/5_current_streak.png',
        achieved: currentStreak >= 5,
      ),
      _FriendAchievement(
        title: '15-day current streak',
        badgeAsset: 'assets/images/15_current_streak.png',
        achieved: currentStreak >= 15,
      ),
      _FriendAchievement(
        title: '30-day current streak',
        badgeAsset: 'assets/images/30_current_streak.png',
        achieved: currentStreak >= 30,
      ),
      _FriendAchievement(
        title: 'Chain builder',
        badgeAsset: 'assets/images/3_chains.png',
        achieved: totalChains >= 3,
      ),
      _FriendAchievement(
        title: 'Chain collector',
        badgeAsset: 'assets/images/5_chains.png',
        achieved: totalChains >= 5,
      ),
      _FriendAchievement(
        title: 'Daily grinder',
        badgeAsset: 'assets/images/50_checkins.png',
        achieved: checkIns >= 50,
      ),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 2 * 16) / 3;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Achievements',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: achievements.map((a) {
                    Widget icon = Image.asset(
                      a.badgeAsset,
                      width: 72,
                      height: 72,
                    );
                    if (!a.achieved) {
                      icon = ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                        child: icon,
                      );
                    }

                    return SizedBox(
                      width: tileWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          icon,
                          const SizedBox(height: 4),
                          Text(
                            a.title,
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(
                              fontWeight: a.achieved
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FriendAchievement {
  final String title;
  final String badgeAsset;
  final bool achieved;

  _FriendAchievement({
    required this.title,
    required this.badgeAsset,
    required this.achieved,
  });
}

class _FriendHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String bio;
  final String memberSince;
  final String? profilePictureUrl;

  const _FriendHeader({
    required this.displayName,
    required this.email,
    required this.bio,
    required this.memberSince,
    this.profilePictureUrl,
  });

  @override
  Widget build(BuildContext context) {
    String initials = 'U';
    final trimmed = displayName.trim();
    if (trimmed.isNotEmpty) {
      final parts = trimmed.split(' ');
      initials = parts.length == 1
          ? parts.first.substring(0, 1).toUpperCase()
          : (parts.first[0] + parts.last[0]).toUpperCase();
    }

    final text = Theme.of(context).textTheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (profilePictureUrl == null ||
                        profilePictureUrl!.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FullScreenImagePage(
                          imageUrl: profilePictureUrl!,
                          heroTag: 'friend_avatar_$email',
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'friend_avatar_$email',
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF7B61FF),
                      backgroundImage: (profilePictureUrl != null &&
                              profilePictureUrl!.isNotEmpty)
                          ? NetworkImage(profilePictureUrl!)
                          : null,
                      child: (profilePictureUrl == null ||
                              profilePictureUrl!.isEmpty)
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: text.bodySmall?.copyWith(color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (bio.isNotEmpty) ...[
              Text(
                'Bio',
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                bio,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            if (memberSince.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Member since $memberSince',
                    style: text.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FriendStatsSection extends StatelessWidget {
  final List<ProfileStat> stats;

  const _FriendStatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: stats[0].icon,
                    value: stats[0].value,
                    label: stats[0].label,
                    iconColor: stats[0].color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    icon: stats[1].icon,
                    value: stats[1].value,
                    label: stats[1].label,
                    iconColor: stats[1].color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: stats[2].icon,
                    value: stats[2].value,
                    label: stats[2].label,
                    iconColor: stats[2].color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    icon: stats[3].icon,
                    value: stats[3].value,
                    label: stats[3].label,
                    iconColor: stats[3].color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommonChainsSection extends StatelessWidget {
  final String currentUserId;
  final String friendUserId;
  final ChainService chainService;

  const _CommonChainsSection({
    required this.currentUserId,
    required this.friendUserId,
    required this.chainService,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return StreamBuilder<List<Chain>>(
      stream: chainService.streamJoinedChains(currentUserId),
      builder: (context, currentSnap) {
        final myChains = currentSnap.data ?? [];

        if (myChains.isEmpty) {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Chains in common',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You are not in any chains together yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<List<Chain>>(
          future: _loadCommonChains(myChains, friendUserId),
          builder: (context, snap) {
            final common = snap.data ?? [];

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chains in common',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (snap.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (common.isEmpty)
                      const Text(
                        'You are not in any chains together yet.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      Column(
                        children: common
                            .map(
                              (c) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.link,
                                    color: Colors.deepPurple),
                                title: Text(c.title),
                                subtitle: Text('${c.members} • ${c.days}'),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Chain>> _loadCommonChains(
    List<Chain> myChains,
    String friendUserId,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final common = <Chain>[];

    for (final c in myChains) {
      try {
        final snap = await firestore
            .collection('chains')
            .doc(c.id)
            .collection('members')
            .where('userId', isEqualTo: friendUserId)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          common.add(c);
        }
      } catch (_) {
        // Ignore errors per-chain; just skip if we can't read.
      }
    }

    return common;
  }
}


