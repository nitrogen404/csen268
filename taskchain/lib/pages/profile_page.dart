import 'package:flutter/material.dart';
import 'dart:io';
import '../models/profile.dart';
import '../widgets/stat_tile.dart';
import 'edit_profile_page.dart';
import '../services/camera_service.dart';

// --- Main Profile Page Widget ---
class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final List<ProfileStat> _stats = const [
    ProfileStat('8', 'Total Chains', Icons.people_alt, AppColors.statTotalChains),
    ProfileStat('42', 'Longest Streak', Icons.local_fire_department, AppColors.statLongestStreak),
    ProfileStat('156', 'Check-ins', Icons.calendar_today, AppColors.statCheckIns),
    ProfileStat('87%', 'Success Rate', Icons.trending_up, AppColors.statSuccessRate),
  ];

  final List<Activity> _activities = const [
    Activity('Completed Daily Reading', '2 hours ago', Icons.accessibility_new, AppColors.statCheckIns),
    Activity('Joined Morning Workout chain', 'Yesterday', Icons.people_alt_outlined, AppColors.statTotalChains),
    Activity('Achieved 10-day streak 🥳', '2 days ago', Icons.local_fire_department, AppColors.statLongestStreak),
  ];

  final CameraService _cameraService = CameraService();
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    // listen to global notifier so header updates immediately when image changes
    CameraService.profileImageNotifier.addListener(() {
      if (mounted) setState(() => _profileImagePath = CameraService.profileImageNotifier.value);
    });
  }

  Future<void> _loadProfileImage() async {
    final path = await _cameraService.getSavedProfileImagePath();
    if (mounted) setState(() => _profileImagePath = path);
  }

  Future<void> _onEditProfile(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
    // Reload image after returning from edit page
    await _loadProfileImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER SECTION - Custom gradient header
            _ProfileHeader(imagePath: _profileImagePath, onEdit: () => _onEditProfile(context)),

            const SizedBox(height: 20),

            // 2x2 STAT GRID
            _StatGrid(stats: _stats),

            // CURRENT STREAK CARD
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
                              Icon(Icons.local_fire_department, color: AppColors.statLongestStreak, size: 20),
                              SizedBox(width: 8),
                              Text('Current Streak', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Text('12', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Text('Keep it going!', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 10),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: LinearProgressIndicator(
                          value: 12 / 30,
                          minHeight: 8,
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.statLongestStreak),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('18 more days to reach your longest streak', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),

            // RECENT ACTIVITY
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ..._activities.map((activity) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: activity.iconColor.withOpacity(0.1),
                    child: Icon(activity.icon, color: activity.iconColor, size: 22),
                  ),
                  title: Text(activity.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(activity.time),
                )).toList(),

            // PREMIUM CARD
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
                  const Icon(Icons.workspace_premium, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  const Text('Already Premium!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('Thank you for supporting Chainz', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: const Text('Manage Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Padding for the floating nav bar
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}


class _ProfileHeader extends StatelessWidget {
  final String? imagePath;
  final Future<void> Function()? onEdit;

  const _ProfileHeader({this.imagePath, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                onPressed: () async {
                  if (onEdit != null) await onEdit!();
                },
                child: Text(
                  'Edit Profile',
                  style: textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFFFC72C),
            backgroundImage: imagePath != null ? FileImage(File(imagePath!)) : null,
            child: imagePath == null ? const Text('AJ', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)) : null,
          ),
          const SizedBox(height: 10),
          Text(
            'Alex Johnson',
            style: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              '👑 Premium Member',
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