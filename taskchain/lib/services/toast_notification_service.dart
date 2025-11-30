import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<StreamSubscription> _subscriptions = [];
  String? _currentChainId;

  /// Called by ChainDetailPage to mark which chain is currently open.
  void setCurrentChain(String? chainId) {
    _currentChainId = chainId;
  }

  /// Begin listening for new messages on the given chain IDs.
  void startListening(List<String> chainIds) {
    _clearSubscriptions();

    if (chainIds.isEmpty) return;

    for (final id in chainIds) {
      final sub = _firestore
          .collection('chains')
          .doc(id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isEmpty) return;

        // Do not show toast for the chain currently open in the detail page.
        if (_currentChainId != null && _currentChainId == id) {
          return;
        }

        final data = snapshot.docs.first.data();
        final sender = data['senderName'] ?? 'User';
        final text = data['text'] ?? '';

        _showToast(sender, text);
      });

      _subscriptions.add(sub);
    }
  }

  void _showToast(String sender, String text) {
    if (text.trim().isEmpty) return;

    Fluttertoast.showToast(
      msg: '$sender: $text',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  /// Used by RootShell dispose to stop listening.
  void stopListening() {
    _clearSubscriptions();
  }

  /// Optional: same as stopListening, if you call dispose() instead.
  void dispose() {
    _clearSubscriptions();
  }

  void _clearSubscriptions() {
    for (var s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }
}
