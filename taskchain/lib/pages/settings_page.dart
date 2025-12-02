import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/auth_service.dart';
import '../pages/sign_in_page.dart';
import '../cubits/settings_cubit.dart';
import '../models/app_settings.dart';
import 'help_support_page.dart';
import 'privacy_policy_page.dart';
import 'about_page.dart';
import 'chatbot_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final AppSettings settings = state.settings ?? const AppSettings();
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: cs.background,
          appBar: AppBar(
            title: const Text("Settings"),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              _sectionHeader("NOTIFICATIONS"),

              _toggleTile(
                icon: Icons.notifications_active_outlined,
                title: "Notifications",
                subtitle: "Enable app notifications",
                value: settings.notificationsEnabled,
                onChanged: (v) => context
                    .read<SettingsCubit>()
                    .toggleNotifications(v),
              ),
              _toggleTile(
                icon: Icons.alarm_outlined,
                title: "Daily Reminders",
                subtitle: "Get notified to check in",
                value: settings.remindersEnabled,
                onChanged: (v) => context
                    .read<SettingsCubit>()
                    .toggleReminders(v),
              ),

              const SizedBox(height: 8),
              _sectionDivider(),

              _sectionHeader("PREFERENCES"),

              ListTile(
                leading: const Icon(
                  Icons.dark_mode_outlined,
                  color: Colors.deepPurple,
                ),
                title: Text(
                  "Theme",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  settings.darkMode == 'dark'
                      ? 'Dark'
                      : settings.darkMode == 'light'
                          ? 'Light'
                          : 'System',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: DropdownButton<String>(
                  value: settings.darkMode,
                  items: const [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: 'light',
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: 'dark',
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsCubit>().toggleDarkMode(value);
                    }
                  },
                ),
              ),

              ListTile(
                leading: const Icon(
                  Icons.language_outlined,
                  color: Colors.green,
                ),
                title: Text(
                  "Language",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  settings.language.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: DropdownButton<String>(
                  value: settings.language,
                  items: const [
                    DropdownMenuItem(
                      value: 'en',
                      child: Text('English'),
                    ),
                    DropdownMenuItem(
                      value: 'es',
                      child: Text('Español'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsCubit>().setLanguage(value);
                    }
                  },
                ),
              ),

              const SizedBox(height: 8),
              _sectionDivider(),

              _sectionHeader("PREMIUM FEATURES"),

              _cardTile(
                icon: Icons.smart_toy,
                color: const Color(0xFF7B61FF),
                title: "AI Assistant",
                subtitle: "Get personalized advice about your chains",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChatbotPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),
              _sectionDivider(),

              _sectionHeader("SUPPORT & ABOUT"),

              _cardTile(
                icon: Icons.help_outline,
                color: Colors.blueAccent,
                title: "Help & Support",
                subtitle: "Get help with TaskChain",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HelpSupportPage(),
                    ),
                  );
                },
              ),
              _cardTile(
                icon: Icons.privacy_tip_outlined,
                color: Colors.green,
                title: "Privacy Policy",
                subtitle: "How we protect your data",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
              _cardTile(
                icon: Icons.info_outline,
                color: Colors.grey,
                title: "About TaskChain",
                subtitle: "Version 1.0.0",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AboutPage(),
                    ),
                  );
                },
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
                    border: Border.all(
                        color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 13),
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
      },
    );
  }

  Widget _sectionHeader(String title) {
    final cs = Theme.of(context).colorScheme;
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
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SwitchListTile(
      secondary: Icon(icon, color: cs.primary),
      title: Text(
        title,
        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: text.bodySmall,
      ),
      value: value,
      onChanged: onChanged,
      activeColor: cs.primary,
    );
  }

  Widget _cardTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: text.bodySmall,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _sectionDivider() {
    final cs = Theme.of(context).colorScheme;
    return Divider(color: cs.outlineVariant, thickness: 1, height: 20);
  }

  // Updated sign-out logic
  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Sign Out"),
        content: const Text(
          "Are you sure you want to log out of your account?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
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
