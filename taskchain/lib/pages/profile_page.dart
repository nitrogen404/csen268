import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile.dart';
import '../widgets/stat_tile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/chain_service.dart';
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
  final String displayName;
  final String email;
  final bool isPremium;
  final String? profilePictureUrl;

  const _ProfileHeader({
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
          CircleAvatar(
            radius: 40,
            backgroundImage: (profilePictureUrl != null &&
                    profilePictureUrl!.isNotEmpty)
                ? NetworkImage(profilePictureUrl!)
                : null,
            backgroundColor: const Color(0xFFFFC72C),
            child: (profilePictureUrl == null || profilePictureUrl!.isEmpty)
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