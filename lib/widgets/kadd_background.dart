import 'package:flutter/material.dart';
import '../theme.dart';

/// The soft two-tone radial glow behind every screen in kadd-mockups.html
/// (`radial-gradient` at top-left in signal orange, bottom-right in unlock
/// lime, over the ink base). Flutter's `RadialGradient` alone can't
/// replicate an off-center glow cleanly the way CSS's positioned
/// radial-gradient can, so this is hand-painted with two blurred circles
/// instead — closer to the mockup than any built-in gradient widget gets.
class KaddBackground extends StatelessWidget {
  final Widget child;
  const KaddBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.ink,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _GlowPainter()),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final signalGlow = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.signal.withOpacity(0.10), AppColors.signal.withOpacity(0.0)],
      ).createShader(
        Rect.fromCircle(center: Offset(size.width * 0.15, size.height * 0.08), radius: size.width * 0.55),
      );
    canvas.drawRect(Offset.zero & size, signalGlow);

    final unlockGlow = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.unlock.withOpacity(0.06), AppColors.unlock.withOpacity(0.0)],
      ).createShader(
        Rect.fromCircle(center: Offset(size.width * 0.85, size.height * 0.92), radius: size.width * 0.55),
      );
    canvas.drawRect(Offset.zero & size, unlockGlow);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) => false;
}
