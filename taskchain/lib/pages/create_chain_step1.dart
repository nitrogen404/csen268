import 'package:flutter/material.dart';
import 'create_chain_step2.dart';
import '../main.dart'; // For navIndex

class CreateChainStep1 extends StatefulWidget {
  const CreateChainStep1({super.key});

  @override
  State<CreateChainStep1> createState() => _CreateChainStep1State();
}

class _CreateChainStep1State extends State<CreateChainStep1> {
  final _habitController = TextEditingController();
  String frequency = 'Daily';
  DateTime? startDate;
  int duration = 30;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            // Pop if possible; otherwise return to Home tab.
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
              "Step 1 of 2",
              style: text.labelMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: 0.5,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    size: 42,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Habit Details",
                  style:
                      text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  "Tell us about your new habit",
                  style: text.bodyMedium?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Heading above the habit name input
            Text(
              "Habit Name",
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _habitController,
              decoration: InputDecoration(
                hintText: "e.g., Daily Reading",
                filled: true,
                fillColor: cs.surfaceVariant.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              "Frequency",
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _freqOption("Daily"),
            _freqOption("Weekly"),
            _freqOption("Custom"),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: InputDecoration(
                      labelText: "Start Date",
                      hintText: startDate == null
                          ? "Select"
                          : "${startDate!.month}/${startDate!.day}/${startDate!.year}",
                      filled: true,
                      fillColor: cs.surfaceVariant.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Duration (days)",
                      hintText: duration.toString(),
                      filled: true,
                      fillColor: cs.surfaceVariant.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) =>
                        setState(() => duration = int.tryParse(v) ?? 30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Choose something specific and achievable. "Read 10 pages" works better than "Read more."',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                if (_habitController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a habit name')),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateChainStep2(
                      habitName: _habitController.text.trim(),
                      frequency: frequency,
                      startDate: startDate,
                      durationDays: duration,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Continue",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _freqOption(String label) {
    return RadioListTile<String>(
      value: label,
      groupValue: frequency,
      onChanged: (v) => setState(() => frequency = v!),
      title: Text(label),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => startDate = picked);
  }
}
