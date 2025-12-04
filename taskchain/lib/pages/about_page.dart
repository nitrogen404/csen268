import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About TaskChain'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Build better habits together',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'TaskChain helps you create chains with friends, keep streaks alive, '
              'and stay accountable through simple, social check-ins.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Version'),
              subtitle: const Text('1.0.0'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.favorite_outline),
              title: const Text('Made for building habits'),
              subtitle: const Text('Designed to be simple, social and motivating.'),
            ),
          ],
        ),
      ),
    );
  }
}



