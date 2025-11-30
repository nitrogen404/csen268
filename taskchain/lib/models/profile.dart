import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF7B61FF);
  static const Color accentPurple = Color(0xFFFF6EC7);

  static const Color statTotalChains = primaryPurple;
  static const Color statLongestStreak = Color(0xFFFF9900);
  static const Color statCheckIns = Color(0xFF3CB371);
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