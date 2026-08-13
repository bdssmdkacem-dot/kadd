import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'coordinates_translator.dart';
import '../theme.dart';

/// Draws the detected pose over the camera preview. Every landmark is drawn
/// faintly for context; the three landmarks the user actually cares about
/// for push-up form — nose (head), left wrist, right wrist — are drawn
/// larger and turn green the moment [isGoodPosition] is true (head has
/// come down close to hand level, i.e. near the ground).
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final bool isGoodPosition;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
    required this.isGoodPosition,
  });

  static const _trackedTypes = [
    PoseLandmarkType.nose,
    PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist,
  ];

  // Faint context lines: shoulders-elbows-wrists, so the arms are visible
  // even though only head+hands are the "tracked" points.
  static const _contextLines = [
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
  ];

  Offset? _point(PoseLandmarkType type, Size canvasSize) {
    final l = pose.landmarks[type];
    if (l == null) return null;
    return Offset(
      translateX(l.x, canvasSize, imageSize, rotation, cameraLensDirection),
      translateY(l.y, canvasSize, imageSize, rotation, cameraLensDirection),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final contextPaint = Paint()
      ..color = AppColors.textDim.withOpacity(0.5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final pair in _contextLines) {
      final a = _point(pair[0], size);
      final b = _point(pair[1], size);
      if (a != null && b != null) canvas.drawLine(a, b, contextPaint);
    }

    final trackedColor = isGoodPosition ? AppColors.unlock : AppColors.signal;
    final trackedFill = Paint()..color = trackedColor;
    final trackedGlow = Paint()
      ..color = trackedColor.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (final type in _trackedTypes) {
      final p = _point(type, size);
      if (p == null) continue;
      canvas.drawCircle(p, 16, trackedGlow);
      canvas.drawCircle(p, 8, trackedFill);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) =>
      oldDelegate.pose != pose || oldDelegate.isGoodPosition != isGoodPosition;
}
