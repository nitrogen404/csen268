import 'package:flutter/material.dart';
import '../services/message_service.dart';
import '../services/auth_service.dart';
import '../services/notification_badge_service.dart';
import 'chain_card.dart';

class ChainCardWithBadge extends StatelessWidget {
  final String chainId;
  final double progress;
  final String title;
  final String days;
  final String members;
  final VoidCallback? onTap;

  const ChainCardWithBadge({
    super.key,
    required this.chainId,
    required this.progress,
    required this.title,
    required this.days,
    required this.members,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final messageService = MessageService();
    final authService = AuthService();
    final badgeService = NotificationBadgeService();

    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      // User not logged in, show card without badge
      return ChainCard(
        progress: progress,
        title: title,
        days: days,
        members: members,
        onTap: onTap,
        unreadCount: 0,
      );
    }

    return StreamBuilder(
      stream: messageService.getChainMessages(chainId),
      builder: (context, snapshot) {
        int unreadCount = 0;

        if (snapshot.hasData && snapshot.data != null) {
          // Get last read time from storage
          _calculateUnreadCount(
            badgeService,
            chainId,
            currentUser.uid,
            snapshot.data!,
          ).then((count) {
            // This will trigger a rebuild when the future completes
            if (count != unreadCount) {
              unreadCount = count;
            }
          });
        }

        return FutureBuilder<int>(
          future: _calculateUnreadCount(
            badgeService,
            chainId,
            currentUser.uid,
            snapshot.data ?? [],
          ),
          builder: (context, unreadSnapshot) {
            final count = unreadSnapshot.data ?? 0;
            
            return ChainCard(
              progress: progress,
              title: title,
              days: days,
              members: members,
              onTap: onTap,
              unreadCount: count,
            );
          },
        );
      },
    );
  }

  Future<int> _calculateUnreadCount(
    NotificationBadgeService badgeService,
    String chainId,
    String userId,
    List messages,
  ) async {
    if (messages.isEmpty) return 0;

    final lastReadTime = await badgeService.getLastReadTime(chainId, userId);
    
    if (lastReadTime == null) {
      // Never read, all messages are unread
      return messages.length;
    }

    // Count messages after last read time
    int count = 0;
    for (var message in messages) {
      if (message.timestamp.isAfter(lastReadTime)) {
        count++;
      }
    }

    return count;
  }
}

