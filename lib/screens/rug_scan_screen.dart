import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/prayer.dart';
import '../services/rug_classifier.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Camera screen that runs the on-device rug classifier and unlocks all
/// apps for this prayer's window once confidence crosses [_confidenceGate].
///
/// The classifier itself lives in RugClassifier (see
/// services/rug_classifier.dart, not yet created) and wraps a TFLite model
/// trained on prayer-rug photos. See assets/models/README.md for the
/// dataset-collection plan — that model does not exist yet and is the main
/// blocker before this screen works end-to-end.
class RugScanScreen extends StatefulWidget {
  final PrayerName prayer;
  const RugScanScreen({super.key, required this.prayer});

  @override
  State<RugScanScreen> createState() => _RugScanScreenState();
}

class _RugScanScreenState extends State<RugScanScreen> {
  CameraController? _controller;
  final _classifier = RugClassifier();
  double? _confidence;
  bool _verifying = false;
  bool _showSuccess = false;

  static const _confidenceGate = 0.85;

  @override
  void initState() {
    super.initState();
    _setup();
    _classifier.load(); // no-op if the model asset isn't bundled yet
  }

  Future<void> _setup() async {
    final cameras = await availableCameras();
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
    await controller.initialize();
    if (!mounted) return;
    setState(() => _controller = controller);
  }

  Future<void> _capture() async {
    if (_controller == null || _verifying) return;
    setState(() => _verifying = true);

    final file = await _controller!.takePicture();
    final confidence = await _classify(file.path);

    setState(() {
      _confidence = confidence;
      _verifying = false;
    });

    if (confidence >= _confidenceGate) {
      HapticFeedback.heavyImpact();
      setState(() => _showSuccess = true);
      await context.read<AppState>().onRugVerified();
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context);
    } else {
      HapticFeedback.lightImpact(); // gentle nudge: try again, not a failure buzz
    }
  }

  /// Delegates to RugClassifier. Returns 0.0 (fails closed) until
  /// assets/models/rug_classifier.tflite actually exists — see
  /// assets/models/README.md for the training plan.
  Future<double> _classify(String imagePath) => _classifier.classify(imagePath);

  @override
  void dispose() {
    _controller?.dispose();
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(child: CameraPreview(_controller!))
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
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('🕌 ${widget.prayer.labelAr}', style: AppTextStyles.kufi(size: 12, color: AppColors.unlock)),
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
            Center(
              child: Container(
                width: 220,
                height: 290,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.unlock, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: 18,
              right: 18,
              child: Column(
                children: [
                  if (_confidence != null)
                    Text(
                      _confidence! >= _confidenceGate
                          ? 'تم التعرف على السجادة — ${(_confidence! * 100).toStringAsFixed(0)}٪'
                          : 'لم يتم التعرف بعد — قرّب السجادة أكثر',
                      style: AppTextStyles.body(
                        size: 12,
                        weight: FontWeight.w600,
                        color: _confidence! >= _confidenceGate ? AppColors.unlock : AppColors.signal,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ضع السجادة كاملة داخل الإطار وثبّت الهاتف حتى تكتمل الدقة',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(size: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _verifying ? AppColors.textFaint : AppColors.signal,
                    ),
                    child: _verifying
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.white),
                  ),
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
                          Text('تقبّل الله 🤲', style: AppTextStyles.kufi(size: 20)),
                          const SizedBox(height: 4),
                          Text('تطبيقاتك فتحت', style: AppTextStyles.body(size: 13, color: AppColors.textDim)),
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
