import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'notification_badge_service.dart';
import 'dart:async';

class ToastNotificationService {
  static final ToastNotificationService _instance = ToastNotificationService._internal();
  factory ToastNotificationService() => _instance;
  ToastNotificationService._internal();

  final MessageService _messageService = MessageService();
  final AuthService _authService = AuthService();
  final NotificationBadgeService _badgeService = NotificationBadgeService();
  
  final Map<String, StreamSubscription> _subscriptions = {};
  BuildContext? _context;
  String? _currentChainId; // Track which chain user is currently viewing

  // Initialize with app context
  void initialize(BuildContext context) {
    _context = context;
  }

  // Set current chain being viewed (to avoid showing notifications for current chain)
  void setCurrentChain(String? chainId) {
    _currentChainId = chainId;
  }

  // Start listening for messages on specific chains
  void startListening(List<String> chainIds) {
    final currentUser = _authService.currentUser;
    if (currentUser == null || _context == null) return;

    // Clean up old subscriptions
    stopListening();

    // Subscribe to each chain
    for (String chainId in chainIds) {
      final subscription = _messageService.getChainMessages(chainId).listen((messages) async {
        if (messages.isEmpty) return;

        // Get the latest message
        final latestMessage = messages.last;

        // Don't show notification for own messages
        if (latestMessage.senderId == currentUser.uid) return;

        // Don't show notification if viewing this chain
        if (_currentChainId == chainId) return;

        // Check if this message is new (unread)
        final lastReadTime = await _badgeService.getLastReadTime(chainId, currentUser.uid);
        
        if (lastReadTime == null || latestMessage.timestamp.isAfter(lastReadTime)) {
          // Show toast for new message
          _showToast(latestMessage);
        }
      });

      _subscriptions[chainId] = subscription;
    }
  }

  // Stop all listeners
  void stopListening() {
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  // Show toast notification
  void _showToast(Message message) {
    if (_context == null || !_context!.mounted) return;

    // Get chain title from chainId (you can enhance this with a mapping)
    final chainTitle = _getChainTitle(message.chainId);

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade300,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.message,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$chainTitle • ${message.senderName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.deepPurple.shade300,
          onPressed: () {
            // Navigate to chain detail
            // This will be handled by the caller
          },
        ),
      ),
    );

    // Play a sound effect (optional - can add audio plugin)
    // AudioPlayer().play('assets/sounds/notification.mp3');
  }

  // Helper to get chain title from ID
  String _getChainTitle(String chainId) {
    // Map chain IDs to titles
    final chainTitles = {
      'chain_1': 'Daily Reading',
      'chain_2': 'Morning Workout',
      'chain_3': 'Learn Spanish',
    };
    return chainTitles[chainId] ?? 'Chain';
  }

  // Dispose
  void dispose() {
    stopListening();
    _context = null;
  }
}

