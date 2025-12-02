import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'full_screen_image_page.dart';

class ChainImagesGrid extends StatelessWidget {
  final String chainId;

  const ChainImagesGrid({required this.chainId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chains')
          .doc(chainId)
          .collection('messages')
          .where('imageUrl', isGreaterThan: '')
          .orderBy('imageUrl')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No images shared yet.'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final url = data['imageUrl'] as String?;
            if (url == null || url.isEmpty) {
              return const SizedBox.shrink();
            }
            return GestureDetector(
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => FullScreenImagePage(
                      imageUrl: url,
                      heroTag: 'media_${this.chainId}_$index',
                    ),
                  ),
                );
              },
              child: Hero(
                tag: 'media_${this.chainId}_$index',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ChainRecordingsList extends StatelessWidget {
  final String chainId;

  const ChainRecordingsList({required this.chainId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chains')
          .doc(chainId)
          .collection('messages')
          .where('audioUrl', isGreaterThan: '')
          .orderBy('audioUrl')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No recordings shared yet.'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final senderName =
                (data['senderName'] as String?) ?? 'Unknown';
            final ts = (data['timestamp'] as Timestamp?)?.toDate();
            String when = '';
            if (ts != null) {
              when =
                  '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
            }
            return ListTile(
              leading: const Icon(Icons.mic, color: Colors.redAccent),
              title: Text(senderName),
              subtitle: Text(when.isNotEmpty ? when : 'Voice message'),
            );
          },
        );
      },
    );
  }
}


