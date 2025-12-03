import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
              'Your privacy matters',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'This is a simple summary of how TaskChain uses your data. '
              'It is placeholder text and can be replaced with the full legal policy later.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 24),
            _bullet(text, 'We store your chains, messages and profile securely in Firestore.'),
            const SizedBox(height: 8),
            _bullet(text, 'Your email is used only for login, notifications and friend discovery.'),
            const SizedBox(height: 8),
            _bullet(text, 'You can delete chains you own, and leave chains you no longer want.'),
            const SizedBox(height: 8),
            _bullet(text, 'We do not sell your personal data.'),
          ],
        ),
      ),
    );
  }

  Widget _bullet(TextTheme text, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(
          child: Text(
            body,
            style: text.bodyMedium,
          ),
        ),
      ],
    );
  }
}



