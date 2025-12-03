import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Need a hand?',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Here are a few ways to get help with TaskChain.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Email support'),
              subtitle:
                  const Text('Reach out if something is broken or confusing.'),
              onTap: () {
                // Placeholder – can be wired to open email later.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email support coming soon.'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Getting started'),
              subtitle:
                  const Text('Learn how chains, streaks and friends work.'),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Report a bug'),
              subtitle: const Text('Tell us when something is not working.'),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}



