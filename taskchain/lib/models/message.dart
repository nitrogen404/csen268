import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String chainId;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.chainId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.imageUrl,
    required this.timestamp,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final ts = data['timestamp'];
    final DateTime time =
        ts is Timestamp ? ts.toDate() : DateTime.now();

    return Message(
      id: doc.id,
      chainId: data['chainId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: time,
    );
  }
}