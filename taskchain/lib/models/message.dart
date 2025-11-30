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

  Map<String, dynamic> toMap() {
    return {
      'chainId': chainId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime messageTime;
    if (data['timestamp'] != null) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    } else {
      messageTime = DateTime.now();
    }

    return Message(
      id: doc.id,
      chainId: data['chainId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'], // NOW SUPPORTED
      timestamp: messageTime,
    );
  }

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    DateTime messageTime;
    if (map['timestamp'] != null) {
      messageTime = (map['timestamp'] as Timestamp).toDate();
    } else {
      messageTime = DateTime.now();
    }

    return Message(
      id: id,
      chainId: map['chainId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'], // NOW SUPPORTED
      timestamp: messageTime,
    );
  }
}
