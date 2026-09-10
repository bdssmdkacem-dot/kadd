import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _classifier = RugClassifier();
  final List<double> _confidences = <double>[];
  bool _verifying = false;
  bool _showSuccess = false;
  bool _initializing = true;
  String? _error;

  static const _steps = <String>[
    'الخطوة 1 من 3: ضع السجادة كاملة داخل الإطار',
    'الخطوة 2 من 3: غيّر زاوية الهاتف قليلًا',
    'الخطوة 3 من 3: غيّر المسافة قليلًا ثم صوّر',
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _classifier.load();
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('لم يتم العثور على كاميرا');
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _error = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = e.description ?? 'تعذر تشغيل الكاميرا';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'تعذر تجهيز التحقق من السجادة';
      });
    }
  }

  Future<void> _captureStep() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _verifying ||
        _showSuccess ||
        _confidences.length >= RugVerificationPolicy.requiredCaptures) {
      return;
    }

    setState(() => _verifying = true);
    try {
      final file = await controller.takePicture();
      final confidence = await _classifier.classify(file.path);
      if (!mounted) return;

      final next = List<double>.from(_confidences)..add(confidence);
      setState(() {
        _confidences
          ..clear()
          ..addAll(next);
        _verifying = false;
      });
      HapticFeedback.selectionClick();

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
  }

  Future<void> _finishVerification(List<double> confidences) async {
    final passed = RugVerificationPolicy.passes(confidences);
    final average = RugVerificationPolicy.average(confidences);
    if (!passed) {
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لم تكتمل المطابقة المتسقة. متوسط الثقة ${(average * 100).toStringAsFixed(0)}٪. أعد المحاولة من زوايا مختلفة.',
          ),
        ),
      );
      setState(() => _confidences.clear());
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _showSuccess = true);
    try {
      // Pass the requested prayer through to the native validation layer.
      // Native state must still contain the same active prayer lock before
      // any unlock is granted; a stale screen can therefore never unlock it.
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
        const SnackBar(content: Text('انتهت صلاحية قفل هذه الصلاة أو تغيّرت الصلاة النشطة. لم يتم فتح التطبيقات.')),
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
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 48, color: AppColors.signal),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.body(size: 13)),
                          const SizedBox(height: 16),
                          KaddPrimaryButton(label: 'إغلاق', onPressed: () => Navigator.pop(context)),
                        ],
                      )
                    : const CircularProgressIndicator(color: AppColors.unlock),
              ),
            if (!_initializing && _controller != null && _controller!.value.isInitialized)
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
                        KaddCard(
                          color: Colors.black.withOpacity(0.62),
                          child: Column(
                            children: [
                              Text(
                                _showSuccess ? 'تم التحقق' : _steps[currentStep],
                                textAlign: TextAlign.center,
                                style: AppTextStyles.kufi(size: 15, color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'الصلاة: ${widget.prayer.arabicName}',
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
                                KaddPrimaryButton(
                                  label: _verifying ? 'جارٍ التحقق…' : 'التقاط الصورة',
                                  onPressed: _verifying ? null : _captureStep,
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
