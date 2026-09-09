import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';

import '../models/locked_app.dart';
import '../services/exercise_rep_tracker.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/pose_painter.dart';

/// Full-screen exercise verification used by the native lock activity.
/// Camera frames and pose data remain on-device.
class RepCameraScreen extends StatefulWidget {
  final LockedApp app;
  const RepCameraScreen({super.key, required this.app});

  @override
  State<RepCameraScreen> createState() => _RepCameraScreenState();
}

class _RepCameraScreenState extends State<RepCameraScreen> {
  CameraController? _controller;
  final _poseDetector = PoseDetector(options: PoseDetectorOptions());
  final _tracker = ExerciseRepTracker();

  bool _busy = false;
  bool _showSuccess = false;
  bool _completionStarted = false;
  String? _cameraError;
  String? _processingError;

  Pose? _lastPose;
  Size _lastImageSize = Size.zero;
  InputImageRotation _lastRotation = InputImageRotation.rotation0deg;

  int _framesWithoutPose = 0;
  static const _lostTrackingFrames = 20;
  static const _downAngleThreshold = 90.0;
  static const _upGapRatio = 0.30;
  static const _downGapRatio = 0.12;

  static const _deviceOrientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    if (mounted) setState(() => _cameraError = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('لا توجد كاميرا متاحة على هذا الجهاز');

      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      final oldController = _controller;
      _controller = controller;
      setState(() {});
      if (oldController != null) await oldController.dispose();

      await controller.startImageStream(_onFrame);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() => _cameraError = _cameraErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      setState(() => _cameraError = 'تعذر تشغيل الكاميرا: $error');
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'تم رفض صلاحية الكاميرا. اسمح لـ كدّ باستخدام الكاميرا ثم حاول مرة أخرى.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'صلاحية الكاميرا غير متاحة. فعّلها من إعدادات النظام ثم حاول مرة أخرى.';
      case 'CameraAccessRestricted':
        return 'الكاميرا مقيدة حاليًا من النظام.';
      default:
        return 'تعذر تشغيل الكاميرا (${error.code}). حاول مرة أخرى.';
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _completionStarted || !mounted) return;
    _busy = true;
    try {
      final rotation = _currentRotation();
      final inputImage = _toInputImage(image, rotation);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (!mounted || _completionStarted) return;

      if (poses.isEmpty) {
        _framesWithoutPose++;
        setState(() => _lastPose = null);
        return;
      }
      _framesWithoutPose = 0;
      _processingError = null;

      final pose = poses.first;
      final gapRatio = _headHandGapRatio(pose, image.height.toDouble());
      final angle = _elbowAngle(pose);
      final goodPosition = gapRatio != null &&
          gapRatio < _downGapRatio &&
          (angle == null || angle < _downAngleThreshold + 20);
      final upPosition = gapRatio != null && gapRatio > _upGapRatio;

      final counted = _tracker.update(
        goodPosition: goodPosition,
        upPosition: upPosition,
      );

      setState(() {
        _lastPose = pose;
        _lastImageSize = Size(image.width.toDouble(), image.height.toDouble());
        _lastRotation = rotation;
      });

      if (counted) _checkComplete();
    } catch (error, stack) {
      debugPrint('Kadd: pose frame failed: $error');
      debugPrint('Kadd: pose frame stack:\n$stack');
      if (mounted && !_completionStarted) {
        setState(() => _processingError = 'تعذر تحليل هذه اللقطة، سنواصل المحاولة تلقائيًا.');
      }
    } finally {
      _busy = false;
    }
  }

  double? _headHandGapRatio(Pose pose, double imageHeight) {
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    if (nose == null || leftWrist == null || rightWrist == null || imageHeight <= 0) return null;
    final avgWristY = (leftWrist.y + rightWrist.y) / 2;
    return (avgWristY - nose.y).abs() / imageHeight;
  }

  double? _elbowAngle(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[PoseLandmarkType.leftWrist];
    if (shoulder == null || elbow == null || wrist == null) return null;

    final a = atan2(shoulder.y - elbow.y, shoulder.x - elbow.x);
    final b = atan2(wrist.y - elbow.y, wrist.x - elbow.x);
    var angle = (a - b) * 180 / pi;
    angle = angle.abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  InputImageRotation _currentRotation() {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    var compensation = _deviceOrientationDegrees[_controller!.value.deviceOrientation] ?? 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      compensation = (sensorOrientation + compensation) % 360;
    } else {
      compensation = (sensorOrientation - compensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(compensation) ?? InputImageRotation.rotation0deg;
  }

  InputImage? _toInputImage(CameraImage image, InputImageRotation rotation) {
    if (!Platform.isAndroid || _controller == null || image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _checkComplete() {
    if (_completionStarted) return;
    final state = context.read<AppState>();
    final needed = widget.app.repsFor(state.difficulty);
    if (_tracker.reps >= needed) {
      _completionStarted = true;
      _celebrateAndFinish(state);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _celebrateAndFinish(AppState state) async {
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    HapticFeedback.heavyImpact();
    if (mounted) setState(() => _showSuccess = true);
    try {
      await state.onRepsVerified(widget.app);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context);
    } catch (error, stack) {
      debugPrint('Kadd: unlock grant failed: $error');
      debugPrint('Kadd: unlock grant stack:\n$stack');
      if (mounted) {
        setState(() {
          _completionStarted = false;
          _showSuccess = false;
          _processingError = 'تعذر منح وقت الفتح. لم تُحسب الجلسة؛ حاول مرة أخرى.';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  Widget _buildCamera() {
    final controller = _controller!;
    final screenSize = MediaQuery.of(context).size;
    final previewAspectRatio = 1 / controller.value.aspectRatio;
    var scale = screenSize.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: AspectRatio(
            aspectRatio: previewAspectRatio,
            child: Stack(
              children: [
                CameraPreview(controller),
                if (_lastPose != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PosePainter(
                        pose: _lastPose!,
                        imageSize: _lastImageSize,
                        rotation: _lastRotation,
                        cameraLensDirection: controller.description.lensDirection,
                        isGoodPosition: _tracker.isGoodPosition,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final needed = widget.app.repsFor(state.difficulty);

    if (_cameraError != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.ink,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined, size: 58, color: AppColors.signal),
                    const SizedBox(height: 18),
                    Text('لا يمكن بدء التحقق', style: AppTextStyles.kufi(size: 19)),
                    const SizedBox(height: 8),
                    Text(_cameraError!, textAlign: TextAlign.center, style: AppTextStyles.body(size: 12, color: AppColors.textDim)),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(onPressed: _setupCamera, icon: const Icon(Icons.refresh), label: const Text('حاول مرة أخرى')),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(child: _buildCamera())
            else
              const Center(child: CircularProgressIndicator(color: AppColors.unlock)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        border: Border.all(color: (_tracker.isGoodPosition ? AppColors.unlock : AppColors.signal).withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _tracker.isGoodPosition ? '● وضعية جيدة' : '● ضغطات',
                        style: AppTextStyles.kufi(size: 12, color: _tracker.isGoodPosition ? AppColors.unlock : AppColors.signal),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.black.withOpacity(0.4),
                        child: const Icon(Icons.close, size: 15, color: AppColors.textDim),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.4),
              child: Column(
                children: [
                  Text('${_tracker.reps}', style: AppTextStyles.kufi(size: 52)),
                  Text('من $needed ضغطة', style: AppTextStyles.body(size: 12, color: AppColors.textDim)),
                ],
              ),
            ),
            if (_processingError != null)
              Positioned(
                top: 92,
                left: 22,
                right: 22,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(12)),
                  child: Text(_processingError!, textAlign: TextAlign.center, style: AppTextStyles.body(size: 11.5, color: AppColors.signal)),
                ),
              ),
            if (_framesWithoutPose > _lostTrackingFrames)
              Align(
                alignment: const Alignment(0, -0.15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(12)),
                  child: Text('ما قدرتش نشوفك بوضوح — تأكد جسمك كامل داخل الكاميرا والإضاءة كافية', textAlign: TextAlign.center, style: AppTextStyles.body(size: 12.5, color: AppColors.signal)),
                ),
              ),
            Positioned(
              bottom: 56,
              left: 18,
              right: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(12)),
                child: Text('انزل حتى تصير النقاط خضراء، ثم ارفع حتى تمتد ذراعيك بالكامل', textAlign: TextAlign.center, style: AppTextStyles.body(size: 12.5)),
              ),
            ),
            if (_showSuccess)
              Container(
                color: AppColors.ink.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.unlock),
                        child: const Icon(Icons.check, size: 56, color: Color(0xFF1A1F0A)),
                      ),
                      const SizedBox(height: 16),
                      Text('كدّيتها! 💪', style: AppTextStyles.kufi(size: 20)),
                      const SizedBox(height: 4),
                      Text('${widget.app.minutesGranted} دقيقة فتحت لك', style: AppTextStyles.body(size: 13, color: AppColors.textDim)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
