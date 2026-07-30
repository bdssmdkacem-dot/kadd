import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

/// The circular "lock/unlock" ring used on Home and the rep camera screen.
/// [progress] is 0..1. [color] defaults to the signal (effort) accent.
class EffortRing extends StatelessWidget {
  final double progress;
  final double size;
  final Widget? center;
  final Color color;

  const EffortRing({
    super.key,
    required this.progress,
    this.size = 160,
    this.center,
    this.color = AppColors.signal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress: progress.clamp(0, 1), color: color),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..color = AppColors.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
