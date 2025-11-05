import 'package:flutter/material.dart';

// --- Custom Colors for Profile UI (as it uses a custom purple gradient) ---
abstract class AppColors {
  // Primary App Colors (The purple gradient)
  static const Color primaryPurple = Color(0xFF7B61FF); // A vibrant purple/indigo
  static const Color accentPurple = Color(0xFFFF6EC7); // A bright pink/magenta

  // Stat Card Colors
  static const Color statTotalChains = primaryPurple;
  static const Color statLongestStreak = Color(0xFFFF9900); // Orange
  static const Color statCheckIns = Color(0xFF3CB371); // Medium Sea Green
  static const Color statSuccessRate = accentPurple;
}

class ProfileStat {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const ProfileStat(this.value, this.label, this.icon, this.color);
}

class Activity {
  final String title;
  final String time;
  final IconData icon;
  final Color iconColor;
  const Activity(this.title, this.time, this.icon, this.iconColor);
}