import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile.dart';
import '../widgets/stat_tile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'edit_profile_page.dart';

// --- Main Profile Page Widget ---
class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  final _userService = UserService();

  final List<Activity> _activities = const [
    Activity('Completed Daily Reading', '2 hours ago', Icons.accessibility_new,
        AppColors.statCheckIns),
    Activity('Joined Morning Workout chain', 'Yesterday',
        Icons.people_alt_outlined, AppColors.statTotalChains),
    Activity('Achieved 10-day streak 🥳', '2 days ago',
        Icons.local_fire_department, AppColors.statLongestStreak),
  ];

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Please sign in to view your profile',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text('Sign In'),
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load profile',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          final data = snapshot.data?.data() ?? {};

          final displayName =
              (data['displayName'] as String?) ?? user.email ?? 'TaskChain User';
          final email = (data['email'] as String?) ?? user.email ?? '';
          final isPremium = (data['isPremium'] as bool?) ?? false;

          // Stats: use stored values if present, otherwise fall back to defaults
          final totalChains = (data['totalChains'] ?? 0).toString();
          final longestStreak = (data['longestStreak'] ?? 0).toString();
          final checkIns = (data['checkIns'] ?? 0).toString();
          final successRate = data['successRate'] != null
              ? '${data['successRate']}%'
              : '0%';

          final stats = [
            ProfileStat(
                totalChains, 'Total Chains', Icons.people_alt, AppColors.statTotalChains),
            ProfileStat(longestStreak, 'Longest Streak',
                Icons.local_fire_department, AppColors.statLongestStreak),
            ProfileStat(checkIns, 'Check-ins', Icons.calendar_today,
                AppColors.statCheckIns),
            ProfileStat(successRate, 'Success Rate', Icons.trending_up,
                AppColors.statSuccessRate),
          ];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER SECTION - Custom gradient header
                _ProfileHeader(
                  displayName: displayName,
                  email: email,
                  isPremium: isPremium,
                ),

            const SizedBox(height: 20),

                // 2x2 STAT GRID
                _StatGrid(stats: stats),

                // CURRENT STREAK CARD (placeholder driven by longestStreak)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.local_fire_department,
                                      color: AppColors.statLongestStreak,
                                      size: 20),
                                  SizedBox(width: 8),
                                  Text('Current Streak',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text(longestStreak,
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Text('Keep it going!',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 10),
                          // Progress Bar - simple visual placeholder
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: LinearProgressIndicator(
                              value: (int.tryParse(longestStreak) ?? 0) / 30.0,
                              minHeight: 8,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.statLongestStreak),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                              'Stay consistent to beat your longest streak!',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),

                // RECENT ACTIVITY (from Firestore)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Text('Recent Activity',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('activity')
                      .orderBy('timestamp', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Failed to load recent activity.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }
                    final docs = snap.data?.docs ?? [];
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
                            data['description'] as String? ?? 'Completed activity';
                        final chainTitle =
                            data['chainTitle'] as String? ?? '';
                        final ts = data['timestamp'] as Timestamp?;
                        String when = '';
                        if (ts != null) {
                          final dt = ts.toDate();
                          when =
                              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        }
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.statCheckIns.withOpacity(0.1),
                            child: const Icon(Icons.check_circle,
                                color: AppColors.statCheckIns),
                          ),
                          title: Text(desc,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            chainTitle.isNotEmpty ? '$chainTitle • $when' : when,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                // PREMIUM CARD (driven by isPremium flag)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(30.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryPurple, AppColors.accentPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.workspace_premium,
                          color: Colors.white, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        isPremium ? 'Already Premium!' : 'Go Premium',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isPremium
                            ? 'Thank you for supporting TaskChain'
                            : 'Unlock more insights and features',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryPurple,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 12),
                        ),
                        child: Text(
                          isPremium
                              ? 'Manage Subscription'
                              : 'Upgrade to Premium',
                          style:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Padding for the floating nav bar
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

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    String initials = 'U';
    final trimmed = displayName.trim();
    if (trimmed.isNotEmpty) {
      final parts = trimmed.split(' ');
      if (parts.length == 1) {
        initials = parts.first.substring(0, 1).toUpperCase();
      } else {
        initials =
            (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
      }
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
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfilePage(),
                    ),
                  );
                },
                child: Text(
                  'Edit Profile',
                  style: textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFFFFC72C),
              ),
              Text(
                initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            style: textTheme.headlineSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              isPremium ? '👑 Premium Member' : 'Free Member',
              style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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