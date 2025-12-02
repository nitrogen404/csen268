import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF7B61FF);
  static const Color accentPurple = Color(0xFFFF6EC7);

  static const Color statTotalChains = Color(0xFF2196F3); // Blue for people icon
  static const Color statLongestStreak = Color(0xFFFFA500); // Orange/yellow for fire icon
  static const Color statCheckIns = Color(0xFFE53935); // Red for calendar icon
  static const Color statSuccessRate = Color(0xFF4CAF50); // Green for up arrow
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