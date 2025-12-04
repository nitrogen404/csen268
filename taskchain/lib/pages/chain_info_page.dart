import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chain_media_widgets.dart';

class ChainInfoPage extends StatelessWidget {
  final String chainId;
  final String chainTitle;
  final String members;
  final double progress;

  const ChainInfoPage({
    super.key,
    required this.chainId,
    required this.chainTitle,
    required this.members,
    required this.progress,
  });

  String _dateKeyUtc(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  int _getMembersCount() {
    // Parse the members string to get count
    // Format is typically "user1@email.com, user2@email.com"
    if (members.isEmpty) return 0;
    return members.split(',').where((m) => m.trim().isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now().toUtc();
    final todayKey = _dateKeyUtc(today);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Group Info'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7B61FF), Color(0xFFFF6EC7)],
                ),
              ),
              child: Column(
                children: [
                  // Group icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.group,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Group name
                  Text(
                    chainTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Members count
                  Text(
                    '${_getMembersCount()} members',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Progress
                  Text(
                    '${(progress * 100).toInt()}% Complete',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Media Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.photo_library, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Media',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Media tabs
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: cs.primary,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: cs.primary,
                          tabs: const [
                            Tab(text: 'Images'),
                            Tab(text: 'Recordings'),
                          ],
                        ),
                        SizedBox(
                          height: 300,
                          child: TabBarView(
                            children: [
                              ChainImagesGrid(chainId: chainId),
                              ChainRecordingsList(chainId: chainId),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Check-ins Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text(
                        "Today's Check-ins",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('chains')
                        .doc(chainId)
                        .collection('members')
                        .orderBy('joinedAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text('No members in this chain.'),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final email = (data['email'] as String?) ?? 'Unknown user';
                          final lastCheckIn = data['lastCheckInDate'] as String?;
                          final hasCheckedIn = lastCheckIn == todayKey;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: hasCheckedIn
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              child: Icon(
                                hasCheckedIn ? Icons.check : Icons.person,
                                color: hasCheckedIn ? Colors.green : Colors.grey,
                              ),
                            ),
                            title: Text(
                              email.split('@').first,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              hasCheckedIn ? 'Checked in today' : 'Not checked in',
                              style: TextStyle(
                                color: hasCheckedIn ? Colors.green : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            trailing: hasCheckedIn
                                ? Icon(Icons.check_circle, color: Colors.green.shade400)
                                : Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
