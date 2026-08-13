import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';
import '../models/locked_app.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/pose_painter.dart';

/// Counts push-up reps using ML Kit's on-device pose detector.
///
/// Rep-counting logic, per the user's own framing: track the head (nose)
/// and both hands (wrists). The "good"/bottom position is when the head has
/// come down close to hand level — i.e. near the ground — shown live as a
/// green overlay on those three points. A rep counts on the down->up
/// transition, gated by the same head/hand distance in reverse (arms
/// extended, head far from hand level again). The elbow angle is kept as a
/// secondary signal on the way down, mainly to avoid counting a rep if the
/// person merely leans toward the camera without bending their arms.
class RepCameraScreen extends StatefulWidget {
  final LockedApp app;
  const RepCameraScreen({super.key, required this.app});

  @override
  State<RepCameraScreen> createState() => _RepCameraScreenState();
}

enum _RepPhase { up, down }

class _RepCameraScreenState extends State<RepCameraScreen> {
  CameraController? _controller;
  final _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _busy = false;
  int _reps = 0;
  _RepPhase _phase = _RepPhase.up;

  Pose? _lastPose;
  Size _lastImageSize = Size.zero;
  InputImageRotation _lastRotation = InputImageRotation.rotation0deg;
  bool _isGoodPosition = false;

  // Debounce: require the condition to hold for several consecutive frames
  // before acting on it. A single noisy frame (motion blur, brief landmark
  // jump) shouldn't flip the phase or count a rep on its own — this is what
  // "detect movements" needs to mean in practice, not just "read one frame".
  int _consecutiveGoodFrames = 0;
  int _consecutiveUpFrames = 0;
  static const _framesToConfirm = 3;

  // Cooldown: refuse to count a second rep within this window of the last
  // one, as a backstop against the debounce still oscillating on noise.
  DateTime? _lastRepAt;
  static const _minRepInterval = Duration(milliseconds: 500);

  int _framesWithoutPose = 0;
  static const _lostTrackingFrames = 20; // ~a couple seconds at typical frame rate

  static const _downAngleThreshold = 90.0; // elbow angle below this = "down"
  static const _upAngleThreshold = 160.0; // elbow angle above this = "up"

  // Head-to-hand distance, normalized by image height so it holds up across
  // resolutions. Starting estimates — tune these against your own camera
  // placement/distance once you can see the overlay live (see README).
  static const _downGapRatio = 0.12; // head within this fraction of image height from hand level = "good"
  static const _upGapRatio = 0.30; // head this far above hand level = arms fully extended

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, // single-plane on Android, matches _toInputImage below
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() => _controller = controller);
    controller.startImageStream(_onFrame);
  }

  // Maps the device's current physical rotation to the degrees ML Kit
  // expects, before combining it with the camera sensor's own mounting
  // rotation below.
  static const _deviceOrientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future<void> _onFrame(CameraImage image) async {
    if (_busy) return;
    _busy = true;
    try {
      final rotation = _currentRotation();
      final inputImage = _toInputImage(image, rotation);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) {
        _framesWithoutPose++;
        setState(() => _lastPose = null);
        return;
      }
      _framesWithoutPose = 0;

      final pose = poses.first;
      final gapRatio = _headHandGapRatio(pose, image.height.toDouble());
      final angle = _elbowAngle(pose);

      final goodPositionNow = gapRatio != null &&
          gapRatio < _downGapRatio &&
          (angle == null || angle < _downAngleThreshold + 20); // angle is a loose secondary check
      final upPositionNow = gapRatio != null && gapRatio > _upGapRatio;

      // Debounce both directions independently so a brief flicker back
      // toward the opposite state doesn't reset progress instantly.
      _consecutiveGoodFrames = goodPositionNow ? _consecutiveGoodFrames + 1 : 0;
      _consecutiveUpFrames = upPositionNow ? _consecutiveUpFrames + 1 : 0;

      if (_phase == _RepPhase.up && _consecutiveGoodFrames >= _framesToConfirm) {
        _phase = _RepPhase.down;
      } else if (_phase == _RepPhase.down && _consecutiveUpFrames >= _framesToConfirm) {
        final now = DateTime.now();
        final withinCooldown = _lastRepAt != null && now.difference(_lastRepAt!) < _minRepInterval;
        if (!withinCooldown) {
          _phase = _RepPhase.up;
          _reps++;
          _lastRepAt = now;
          _checkComplete();
        }
      }

      setState(() {
        _lastPose = pose;
        _lastImageSize = Size(image.width.toDouble(), image.height.toDouble());
        _lastRotation = rotation;
        // Reflect the debounced state in the overlay, not the raw per-frame
        // reading — otherwise the green flash would flicker faster than the
        // rep logic actually reacts to it, which reads as the app "lying"
        // about what counted.
        _isGoodPosition = _consecutiveGoodFrames >= _framesToConfirm;
      });
    } finally {
      _busy = false;
    }
  }

  /// Vertical distance between the head (nose) and the average hand
  /// (wrist) height, as a fraction of the frame height. Small = head is
  /// close to hand level (near the ground, good push-up depth). Large =
  /// arms extended, head lifted well above hand level.
  double? _headHandGapRatio(Pose pose, double imageHeight) {
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    if (nose == null || leftWrist == null || rightWrist == null) return null;
    if (imageHeight <= 0) return null;

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

  /// Combines the camera sensor's fixed mounting rotation with the phone's
  /// current physical orientation — see [_toInputImage]'s doc comment for
  /// why both matter and combine in opposite directions for front vs. back
  /// cameras.
  InputImageRotation _currentRotation() {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    int rotationCompensation = _deviceOrientationDegrees[_controller!.value.deviceOrientation] ?? 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(rotationCompensation) ?? InputImageRotation.rotation0deg;
  }

  /// Converts a raw [CameraImage] frame into the [InputImage] ML Kit expects.
  ///
  /// Two things make this fiddly and are handled explicitly here:
  ///  1. Rotation: ML Kit wants the image rotation relative to how a person
  ///     would view it upright. That's the camera sensor's own mounting
  ///     rotation (`sensorOrientation`, fixed per device) combined with how
  ///     the phone is currently held (`deviceOrientation`), and the two
  ///     combine in opposite directions for front vs. back cameras.
  ///  2. Format/plane layout: requesting `ImageFormatGroup.nv21` above
  ///     guarantees Android hands back a single interleaved plane, so we can
  ///     pass its bytes straight through instead of manually concatenating
  ///     Y/U/V planes (which is only needed for the default yuv420 format).
  InputImage? _toInputImage(CameraImage image, InputImageRotation rotation) {
    if (_controller == null) return null;

    // We only support Android/NV21 here — this screen is Android-only per
    // the project's current scope (see README).
    if (!Platform.isAndroid) return null;
    if (image.planes.length != 1) return null; // guards against a misconfigured imageFormatGroup
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

  bool _showSuccess = false;

  void _checkComplete() {
    final state = context.read<AppState>();
    final needed = widget.app.repsFor(state.difficulty);
    if (_reps >= needed) {
      _celebrateAndFinish(state);
    } else {
      HapticFeedback.mediumImpact(); // per-rep tick, distinct from the final completion buzz
    }
  }

  Future<void> _celebrateAndFinish(AppState state) async {
    _controller?.stopImageStream();
    HapticFeedback.heavyImpact();
    setState(() => _showSuccess = true);
    await state.onRepsVerified(widget.app);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  /// `CameraController.value.aspectRatio` is reported in the sensor's own
  /// landscape orientation (e.g. 1.77 for 16:9) even though the phone is
  /// held in portrait. Using it directly makes `AspectRatio` lay out a
  /// wide landscape box centered in a portrait screen — a small letterboxed
  /// rectangle, with the pose overlay technically aligned to it but the
  /// whole thing visually "floating" separate from what looks like the
  /// real camera feed. Two fixes combined here:
  ///  1. Invert it (`1 / aspectRatio`) so the box is portrait-shaped.
  ///  2. Scale that box up to fill the screen (cropping overflow) instead
  ///     of leaving it centered with letterboxing on the sides.
  /// The overlay is built inside the exact same AspectRatio+Transform.scale
  /// chain as the preview, not alongside it, so the two can't drift apart —
  /// whatever happens to the video happens identically to the dots.
  Widget _buildFullBleedCameraWithOverlay() {
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
                        isGoodPosition: _isGoodPosition,
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(child: _buildFullBleedCameraWithOverlay())
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
                        border: Border.all(
                          color: (_isGoodPosition ? AppColors.unlock : AppColors.signal).withOpacity(0.4),
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _isGoodPosition ? '● وضعية جيدة' : '● ضغطات',
                        style: AppTextStyles.kufi(
                          size: 12,
                          color: _isGoodPosition ? AppColors.unlock : AppColors.signal,
                        ),
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
                  Text('$_reps', style: AppTextStyles.kufi(size: 52)),
                  Text('من $needed ضغطة', style: AppTextStyles.body(size: 12, color: AppColors.textDim)),
                ],
              ),
            ),
            if (_framesWithoutPose > _lostTrackingFrames)
              Align(
                alignment: const Alignment(0, -0.15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ما قدرتش نشوفك بوضوح — تأكد جسمك كامل داخل الكاميرا والإضاءة كافية',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(size: 12.5, color: AppColors.signal),
                  ),
                ),
              ),
            Positioned(
              bottom: 56,
              left: 18,
              right: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'انزل حتى تصير النقاط خضراء (رأسك قريب من مستوى يديك)، ثم ارفع حتى تمتد ذراعيك بالكامل',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(size: 12.5),
                ),
              ),
            ),
            if (_showSuccess)
              AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: AppColors.ink.withOpacity(0.85),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
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
                          Text('${widget.app.minutesGranted} دقيقة فتحت لك',
                              style: AppTextStyles.body(size: 13, color: AppColors.textDim)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
