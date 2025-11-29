import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../pages/sign_in_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool dailyReminders = true;
  bool groupActivity = true;
  bool achievements = true;
  bool darkMode = false;

  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          _sectionHeader("NOTIFICATIONS"),

          _toggleTile(
            icon: Icons.notifications_active_outlined,
            title: "Daily Reminders",
            subtitle: "Get notified to check in",
            value: dailyReminders,
            onChanged: (v) => setState(() => dailyReminders = v),
          ),
          _toggleTile(
            icon: Icons.group_outlined,
            title: "Group Activity",
            subtitle: "When teammates check in",
            value: groupActivity,
            onChanged: (v) => setState(() => groupActivity = v),
          ),
          _toggleTile(
            icon: Icons.emoji_events_outlined,
            title: "Achievements",
            subtitle: "When you earn badges",
            value: achievements,
            onChanged: (v) => setState(() => achievements = v),
          ),

          const SizedBox(height: 8),
          _sectionDivider(),

          _sectionHeader("PREFERENCES"),

          _toggleTile(
            icon: Icons.dark_mode_outlined,
            title: "Dark Mode",
            subtitle: "Switch to dark theme",
            value: darkMode,
            onChanged: (v) => setState(() => darkMode = v),
          ),

          ListTile(
            leading: const Icon(Icons.language_outlined, color: Colors.green),
            title: const Text("Language",
                style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black)),
            subtitle: const Text("English", style: TextStyle(color: Colors.black87)),
            trailing: const Text("Change", style: TextStyle(color: Colors.blue)),
            onTap: () {},
          ),

          const SizedBox(height: 8),
          _sectionDivider(),

          _sectionHeader("SUPPORT & ABOUT"),

          _cardTile(
            icon: Icons.help_outline,
            color: Colors.blueAccent,
            title: "Help & Support",
            subtitle: "Get help with TaskChain",
            onTap: () {},
          ),
          _cardTile(
            icon: Icons.privacy_tip_outlined,
            color: Colors.green,
            title: "Privacy Policy",
            subtitle: "How we protect your data",
            onTap: () {},
          ),
          _cardTile(
            icon: Icons.info_outline,
            color: Colors.grey,
            title: "About TaskChain",
            subtitle: "Version 1.0.0",
            onTap: () {},
          ),

          const SizedBox(height: 8),
          _sectionDivider(),

          _sectionHeader("ACCOUNT"),

          GestureDetector(
            onTap: () {
              _showSignOutDialog(context);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Sign Out",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Log out of your account",
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 13,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.deepPurple),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.black87)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.deepPurple,
    );
  }

  Widget _cardTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black87)),
        onTap: onTap,
      ),
    );
  }

  Widget _sectionDivider() {
    return Divider(color: Colors.grey.shade200, thickness: 1, height: 20);
  }

  // Updated sign-out logic
  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Sign Out", style: TextStyle(color: Colors.black)),
        content: const Text(
          "Are you sure you want to log out of your account?",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.black87)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SignInPage()),
                  (route) => false,
                );
              }
            },
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }
}
