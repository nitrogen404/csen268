import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<StreamSubscription> _subscriptions = [];

  void startListening(List<String> chainIds) {
    // Clear previous listeners
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // If no chains, do nothing
    if (chainIds.isEmpty) return;

    // Listen to each chain for new messages
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

        final data = snapshot.docs.first.data();
        final sender = data['senderName'] ?? 'User';
        final text = data['text'] ?? '';

        _showToast(sender, text);
      });

      _subscriptions.add(sub);
    }
  }

  void _showToast(String sender, String text) {
    Fluttertoast.showToast(
      msg: '$sender: $text',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void dispose() {
    for (var s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }
}
