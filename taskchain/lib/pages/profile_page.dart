import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/profile.dart';
import '../models/chain.dart';
import '../pages/chain_detail_page.dart';
import '../widgets/stat_tile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/chain_service.dart';
import '../services/friend_service.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  final _userService = UserService();
  final _chainService = ChainService();
  final _friendService = FriendService();

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Please sign in to view your profile',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userService.streamUserProfile(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};

          final displayName =
              data['displayName'] as String? ?? user.email ?? 'TaskChain User';
          final email = data['email'] as String? ?? user.email ?? '';
          final isPremium = data['isPremium'] as bool? ?? false;
          final profilePictureUrl = data['profilePictureUrl'] as String?;

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
          final currentStreakValue = int.tryParse(currentStreak) ?? 0;

          return SingleChildScrollView(
            child: Column(
              children: [
                _ProfileHeader(
                  userId: user.uid,
                  displayName: displayName,
                  email: email,
                  isPremium: isPremium,
                  profilePictureUrl: profilePictureUrl,
                ),
                const SizedBox(height: 20),
                StreamBuilder<int>(
                  stream: _chainService.streamJoinedChainCount(user.uid),
                  builder: (context, countSnap) {
                    final totalChains = countSnap.data?.toString() ?? '0';

                    final stats = [
                      ProfileStat(
                        totalChains,
                        'Joined Chains',
                        Icons.people_alt,
                        AppColors.statTotalChains,
                      ),
                      ProfileStat(
                        longestStreak,
                        'Longest Streak',
                        Icons.local_fire_department,
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
                    ];

                    return _StatGrid(stats: stats);
                  },
                ),
                const SizedBox(height: 16),
                // Inbox: friend requests + chain invites
                _InboxSection(
                  userId: user.uid,
                  friendService: _friendService,
                  chainService: _chainService,
                  currentUserName: displayName,
                  currentUserEmail: email,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: AppColors.statLongestStreak,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Current Streak',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                currentStreak,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: currentStreakValue / 30.0,
                              minHeight: 8,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                AppColors.statLongestStreak,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Text(
                    'Recent Activity',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('activity')
                      .orderBy('timestamp', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'No recent activity yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return Column(
                      children: docs.map((d) {
                        final data = d.data();
                        final desc =
                            data['description'] ?? 'Completed activity';
                        final title = data['chainTitle'] ?? '';
                        final ts = data['timestamp'] as Timestamp?;

                        String when = '';
                        if (ts != null) {
                          final t = ts.toDate();
                          when =
                              '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.statCheckIns.withOpacity(0.1),
                            child: const Icon(
                              Icons.check_circle,
                              color: AppColors.statCheckIns,
                            ),
                          ),
                          title: Text(desc),
                          subtitle: Text(
                            title.isNotEmpty ? '$title • $when' : when,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String userId;
  final String displayName;
  final String email;
  final bool isPremium;
  final String? profilePictureUrl;

  const _ProfileHeader({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.isPremium,
    this.profilePictureUrl,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    String initials = 'U';
    final trimmed = displayName.trim();

    if (trimmed.isNotEmpty) {
      final parts = trimmed.split(' ');
      initials = parts.length == 1
          ? parts.first.substring(0, 1).toUpperCase()
          : (parts.first[0] + parts.last[0]).toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryPurple, AppColors.accentPurple],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfilePage(),
                    ),
                  );
                },
                child: Text(
                  'Edit Profile',
                  style: text.bodyLarge?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
          // Avatar with small QR icon overlay in the bottom-right corner.
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: (profilePictureUrl != null &&
                        profilePictureUrl!.isNotEmpty)
                    ? NetworkImage(profilePictureUrl!)
                    : null,
                backgroundColor: const Color(0xFFFFC72C),
                child: (profilePictureUrl == null ||
                        profilePictureUrl!.isEmpty)
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 4,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _showProfileQr(context),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.qr_code_2,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            style: text.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              isPremium ? 'Premium Member' : 'Free Member',
              style: text.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileQr(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Share your profile',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              QrImageView(
                // Encode email so scanners can send a friend request directly.
                data: email,
                version: QrVersions.auto,
                size: 180,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: cs.primary,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                email,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatGrid extends StatelessWidget {
  final List<ProfileStat> stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: stats[0].icon,
                  value: stats[0].value,
                  label: stats[0].label,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  icon: stats[1].icon,
                  value: stats[1].value,
                  label: stats[1].label,
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
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  icon: stats[3].icon,
                  value: stats[3].value,
                  label: stats[3].label,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InboxSection extends StatelessWidget {
  final String userId;
  final FriendService friendService;
  final ChainService chainService;
  final String currentUserName;
  final String currentUserEmail;

  const _InboxSection({
    required this.userId,
    required this.friendService,
    required this.chainService,
    required this.currentUserName,
    required this.currentUserEmail,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Inbox',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Icon(Icons.inbox_outlined, color: cs.primary),
                ],
              ),
              const SizedBox(height: 12),
              // Friend Requests
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: friendService.streamFriendRequests(userId),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Text(
                      'No friend requests yet.',
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Friend Requests',
                        style: text.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...docs.map((d) {
                        final data = d.data();
                        final fromName =
                            (data['fromDisplayName'] as String?) ?? 'Friend';
                        final fromEmail =
                            (data['fromEmail'] as String?) ?? '';
                        // Only pending requests are streamed; no need
                        // to surface non-pending ones here.

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: cs.primary.withOpacity(0.1),
                            child: Text(
                              fromName.isNotEmpty
                                  ? fromName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(color: cs.primary),
                            ),
                          ),
                          title: Text(fromName),
                          subtitle: Text(
                            fromEmail,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: 'Decline',
                                onPressed: () async {
                                  await friendService
                                      .declineFriendRequest(
                                    currentUserId: userId,
                                    requestId: d.id,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.check),
                                tooltip: 'Accept',
                                onPressed: () async {
                                  await friendService
                                      .acceptFriendRequest(
                                    currentUserId: userId,
                                    currentUserEmail:
                                        currentUserEmail,
                                    currentUserDisplayName:
                                        currentUserName,
                                    requestId: d.id,
                                    requestData: data,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              // Chain Invites
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: friendService.streamChainInvites(userId),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chain Invites',
                        style: text.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...docs.map((d) {
                        final data = d.data();
                        final chainTitle =
                            (data['chainTitle'] as String?) ?? 'Chain';
                        final inviterName =
                            (data['inviterName'] as String?) ?? 'Friend';
                        final status =
                            (data['status'] as String?) ?? 'pending';
                        final isPending = status == 'pending';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                cs.secondaryContainer.withOpacity(0.4),
                            child: const Icon(Icons.link),
                          ),
                          title: Text(chainTitle),
                          subtitle: Text('Invited by $inviterName'),
                          trailing: isPending
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      tooltip: 'Ignore',
                                      onPressed: () async {
                                        await friendService
                                            .updateChainInviteStatus(
                                          currentUserId: userId,
                                          inviteId: d.id,
                                          status: 'declined',
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check),
                                      tooltip: 'Accept & join',
                                      onPressed: () async {
                                        final rawCode =
                                            (data['chainCode'] as String?) ??
                                                '';
                                        final code = rawCode.trim();
                                        if (code.isEmpty) {
                                          return;
                                        }
                                        try {
                                          // First ensure the chain still exists.
                                          final query = await FirebaseFirestore
                                              .instance
                                              .collection('chains')
                                              .where('code', isEqualTo: code)
                                              .limit(1)
                                              .get();

                                          if (query.docs.isEmpty) {
                                            // Chain was deleted or no longer valid.
                                            await friendService
                                                .updateChainInviteStatus(
                                              currentUserId: userId,
                                              inviteId: d.id,
                                              status: 'declined',
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'This chain no longer exists. Invite removed.'),
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          // Join the existing chain.
                                          await chainService.joinChainByCode(
                                            userId: userId,
                                            userEmail: currentUserEmail,
                                            code: code,
                                          );

                                          await friendService
                                              .updateChainInviteStatus(
                                            currentUserId: userId,
                                            inviteId: d.id,
                                            status: 'accepted',
                                          );

                                          // Navigate directly to the joined chain.
                                          if (context.mounted) {
                                            final doc = query.docs.first;
                                            final chain =
                                                Chain.fromFirestore(doc);
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
                                          }
                                        } catch (e) {
                                          // On any error, keep the invite but show feedback.
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to join chain: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                )
                              : Text(
                                  status[0].toUpperCase() +
                                      status.substring(1),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                        );
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              // Friends list (for inviting to chains etc.)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: friendService.streamFriends(userId),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Text(
                      'No friends yet. Add friends from the Members list.',
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Friends',
                        style: text.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...docs.map((d) {
                        final data = d.data();
                        final name =
                            (data['displayName'] as String?) ?? 'Friend';
                        final email = (data['email'] as String?) ?? '';
                        final friendId = (data['userId'] as String?) ?? d.id;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: cs.primary.withOpacity(0.1),
                            child: Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(color: cs.primary),
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.person_add_alt_1),
                                tooltip: 'Invite to chain',
                                onPressed: () {
                                  _showInviteToChainSheet(
                                    context,
                                    friendId: friendId,
                                    friendName: name,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                tooltip: 'Remove friend',
                                onPressed: () async {
                                  final confirmed =
                                      await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Remove friend?'),
                                      content: Text(
                                          'Are you sure you want to remove $name from your friends?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text(
                                            'Remove',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    await friendService.removeFriend(
                                      currentUserId: userId,
                                      friendUserId: friendId,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteToChainSheet(
    BuildContext context, {
    required String friendId,
    required String friendName,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite $friendName to a chain',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: StreamBuilder<List<Chain>>(
                  stream: chainService.streamJoinedChains(userId),
                  builder: (context, snapshot) {
                    final chains = snapshot.data ?? [];
                    if (chains.isEmpty) {
                      return const Center(
                        child: Text('You have no chains yet.'),
                      );
                    }

                    return ListView.builder(
                      itemCount: chains.length,
                      itemBuilder: (context, index) {
                        final c = chains[index];
                        return ListTile(
                          title: Text(c.title),
                          subtitle: Text('${c.members} • ${c.days}'),
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await friendService.sendChainInvite(
                              toUserId: friendId,
                              chainId: c.id,
                              chainTitle: c.title,
                              chainCode: c.code,
                              inviterId: userId,
                              inviterEmail: currentUserEmail,
                              inviterName: currentUserName,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
