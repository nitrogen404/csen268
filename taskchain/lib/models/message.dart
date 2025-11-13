import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String chainId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.chainId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  // Convert Message to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'chainId': chainId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // Create Message from Firestore document
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle null timestamp (server timestamp may not be set yet)
    DateTime messageTime;
    if (data['timestamp'] != null) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    } else {
      messageTime = DateTime.now(); // Fallback to current time
    }
    
    return Message(
      id: doc.id,
      chainId: data['chainId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      text: data['text'] ?? '',
      timestamp: messageTime,
    );
  }

  // Create Message from Map
  factory Message.fromMap(Map<String, dynamic> map, String id) {
    // Handle null timestamp (server timestamp may not be set yet)
    DateTime messageTime;
    if (map['timestamp'] != null) {
      messageTime = (map['timestamp'] as Timestamp).toDate();
    } else {
      messageTime = DateTime.now(); // Fallback to current time
    }
    
    return Message(
      id: id,
      chainId: map['chainId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      text: map['text'] ?? '',
      timestamp: messageTime,
    );
  }
}

