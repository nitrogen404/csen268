import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send a message to a chain
  Future<void> sendMessage({
    required String chainId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      await _firestore.collection('messages').add({
        'chainId': chainId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to send message: $e';
    }
  }

  // Get messages for a specific chain (real-time stream)
  Stream<List<Message>> getChainMessages(String chainId) {
    return _firestore
        .collection('messages')
        .where('chainId', isEqualTo: chainId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  // Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
    } catch (e) {
      throw 'Failed to delete message: $e';
    }
  }

  // Get message count for a chain
  Future<int> getMessageCount(String chainId) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('chainId', isEqualTo: chainId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}

