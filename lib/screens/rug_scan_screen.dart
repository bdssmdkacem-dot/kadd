import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import '../models/prayer.dart';
import '../services/rug_classifier.dart';
import '../services/rug_verification_policy.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/kadd_card.dart';

class RugScanScreen extends StatefulWidget {
  final PrayerName prayer;

  const RugScanScreen({super.key, required this.prayer});

  @override
  State<RugScanScreen> createState() => _RugScanScreenState();
}

class _RugScanScreenState extends State<RugScanScreen> {
  CameraController? _controller;
  final RugClassifier _classifier = RugClassifier();
  final List<double> _confidences = <double>[];
  bool _verifying = false;
  bool _showSuccess = false;
  String? _error;

  static const List<String> _steps = <String>[
    'صوّر السجادة بوضوح',
    'غيّر زاوية التصوير قليلًا',
    'التقط الصورة الأخيرة للتأكد',
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('لا توجد كاميرا متاحة');
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تشغيل الكاميرا. تحقق من صلاحية الكاميرا وحاول مرة أخرى.');
    }
  }

  Future<void> _captureStep() async {
    final controller = _controller;
    if (_verifying || _showSuccess || controller == null || !controller.value.isInitialized) return;

    setState(() => _verifying = true);
    try {
      final image = await controller.takePicture();
      final result = await _classifier.classify(image.path);
      final next = <double>[..._confidences, result];
      if (!mounted) return;
      setState(() {
        _confidences
          ..clear()
          ..addAll(next);
      });
      if (next.length == RugVerificationPolicy.requiredCaptures) {
        await _finishVerification(next);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحليل هذه الصورة. لم تُحسب الخطوة.')),
      );
    }
    if (mounted) setState(() => _verifying = false);
  }

  Future<void> _finishVerification(List<double> confidences) async {
    final passed = RugVerificationPolicy.passes(confidences);
    final average = RugVerificationPolicy.average(confidences);
    if (!passed) {
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() => _confidences.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لم تكتمل المطابقة المتسقة. متوسط الثقة ${(average * 100).toStringAsFixed(0)}٪. أعد المحاولة من زوايا مختلفة.',
          ),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() => _showSuccess = true);
    try {
      await context.read<AppState>().onRugVerified(widget.prayer);
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showSuccess = false;
        _confidences.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح التطبيقات لأن حالة الصلاة لم تعد صالحة. حاول مرة أخرى.')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _confidences.length;
    final currentStep = step >= RugVerificationPolicy.requiredCaptures
        ? RugVerificationPolicy.requiredCaptures - 1
        : step;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(child: CameraPreview(_controller!))
            else
              Center(
                child: _error != null
                    ? Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.body(size: 13))
                    : const CircularProgressIndicator(color: AppColors.unlock),
              ),
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: _verifying || _showSuccess ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                          const Spacer(),
                          Text('تحقق السجادة', style: AppTextStyles.kufi(size: 17, color: Colors.white)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _showSuccess ? 'تم التحقق' : _steps[currentStep],
                              textAlign: TextAlign.center,
                              style: AppTextStyles.kufi(size: 15, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'الصلاة: ${widget.prayer.labelAr}',
                              style: AppTextStyles.body(size: 12, color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            if (_showSuccess)
                              const Icon(Icons.verified_rounded, size: 44, color: AppColors.unlock)
                            else ...[
                              LinearProgressIndicator(
                                value: _confidences.length / RugVerificationPolicy.requiredCaptures,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.unlock),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _verifying || _controller == null ? null : _captureStep,
                                  icon: _verifying
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.camera_alt_outlined),
                                  label: Text(_verifying ? 'جارٍ التحقق...' : 'التقاط الصورة'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
