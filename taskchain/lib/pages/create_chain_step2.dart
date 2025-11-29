import 'package:flutter/material.dart';
import '../main.dart';
import '../services/chain_service.dart';
import '../services/auth_service.dart';
import 'chain_detail_page.dart';

class CreateChainStep2 extends StatefulWidget {
  final String habitName;
  final String frequency;
  final DateTime? startDate;
  final int durationDays;

  const CreateChainStep2({
    super.key,
    required this.habitName,
    required this.frequency,
    required this.startDate,
    required this.durationDays,
  });

  @override
  State<CreateChainStep2> createState() => _CreateChainStep2State();
}

class _CreateChainStep2State extends State<CreateChainStep2> {
  String selectedTheme = 'Ocean';

  final ChainService _chainService = ChainService();
  final AuthService _authService = AuthService();

  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              navIndex.value = 0;
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Create New Chain",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              "Step 2 of 2",
              style: text.labelMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: 1.0,
            backgroundColor: cs.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(cs.primary),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const SizedBox(height: 12),

            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.palette_outlined, size: 42, color: cs.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  "Personalize & Share",
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Customize your chain and invite friends",
                  style: text.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),

            const SizedBox(height: 28),

            Text(
              "Choose Theme",
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _themeOption("Ocean",
                    [const Color(0xFF7B61FF), const Color(0xFF4C8DFF)]),
                _themeOption("Forest",
                    [const Color(0xFF14C38E), const Color(0xFF3CCF4E)]),
                _themeOption("Sunset",
                    [const Color(0xFFFF6EC7), const Color(0xFFFF9A9E)]),
                _themeOption("Energy",
                    [const Color(0xFFFF5A5F), const Color(0xFFFFC371)]),
              ],
            ),

            const SizedBox(height: 28),

            Text(
              "Invite Friends (Optional)",
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            TextField(
              decoration: InputDecoration(
                hintText: "friend@example.com",
                prefixIcon: const Icon(Icons.person_add_outlined),
                filled: true,
                fillColor: cs.surfaceVariant.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Expanded(
                    child: Text(
                      "taskchain.app/join/abc123",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.copy, size: 18),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Invited Friends",
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: cs.primary.withOpacity(0.1),
                      child: const Text("SJ"),
                    ),
                    title: const Text("Sarah Johnson"),
                    subtitle: const Text("Pending"),
                    trailing:
                        Icon(Icons.hourglass_empty_rounded, color: cs.primary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _isCreating ? null : _createChain,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Create Chain",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(String name, List<Color> colors) {
    final isSelected = selectedTheme == name;

    return GestureDetector(
      onTap: () => setState(() => selectedTheme = name),
      child: Container(
        width: (MediaQuery.of(context).size.width / 2) - 28,
        height: 90,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createChain() async {
    final user = _authService.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create a chain')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final chain = await _chainService.createChain(
        ownerId: user.uid,
        ownerEmail: user.email ?? '',
        title: widget.habitName,
        frequency: widget.frequency,
        startDate: widget.startDate,
        durationDays: widget.durationDays,
        theme: selectedTheme,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chain created! Share your code: ${chain.code}')),
      );

      navIndex.value = 0;

      Navigator.of(context).popUntil((r) => r.isFirst);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChainDetailPage(
            chainId: chain.id,
            chainTitle: chain.title,
            members: chain.members,
            progress: chain.progress,
            code: chain.code,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create chain: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }
}
