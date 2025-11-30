import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage({
    required String chainId,
    required String senderId,
    required String senderName,
    required String text,
    String? imageUrl,
  }) async {
    try {
      await _firestore.collection('messages').add({
        'chainId': chainId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to send message: $e';
    }
  }

  Stream<List<Message>> getChainMessages(String chainId) {
    return _firestore
        .collection('messages')
        .where('chainId', isEqualTo: chainId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
    } catch (e) {
      throw 'Failed to delete message: $e';
    }
  }

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
