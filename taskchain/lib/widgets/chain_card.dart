import 'package:flutter/material.dart';
import 'progress_ring.dart';

class ChainCard extends StatelessWidget {
  final double progress;
  final String title;
  final String days;
  final String members;
  final VoidCallback? onTap;
  final int unreadCount;

  const ChainCard({
    super.key,
    required this.progress,
    required this.title,
    required this.days,
    required this.members,
    this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProgressRing(progress: progress, size: 60, stroke: 7),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, size: 16),
                      const SizedBox(width: 6),
                      Text(days, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 14),
                      const Icon(Icons.group, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        members,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: cs.surfaceVariant.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
            ),
          ),
          // Unread badge
          if (unreadCount > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
