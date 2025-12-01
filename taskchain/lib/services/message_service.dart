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
    String? audioUrl,
  }) async {
    final ref = _firestore
        .collection('chains')
        .doc(chainId)
        .collection('messages')
        .doc();

    await ref.set({
      'chainId': chainId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Message>> getChainMessages(String chainId) {
    return _firestore
        .collection('chains')
        .doc(chainId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  Future<void> deleteMessage(String chainId, String messageId) async {
    await _firestore
        .collection('chains')
        .doc(chainId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<int> getMessageCount(String chainId) async {
    final snapshot = await _firestore
        .collection('chains')
        .doc(chainId)
        .collection('messages')
        .get();
    return snapshot.docs.length;
  }
}