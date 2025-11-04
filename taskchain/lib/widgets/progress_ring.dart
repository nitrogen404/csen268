import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final double stroke;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 56,
    this.stroke = 6,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4);
    final fg = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          bg: bg,
          fg: fg,
          stroke: stroke,
          progress: progress,
        ),
        child: Center(
          child: Text(
            "${(progress * 100).round()}%",
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color bg, fg;
  final double stroke;
  final double progress;

  _RingPainter({
    required this.bg,
    required this.fg,
    required this.stroke,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2 - stroke / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2,
      false,
      base..color = bg,
    );

    // progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      base..color = fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.bg != bg ||
      old.fg != fg ||
      old.stroke != stroke;
}
