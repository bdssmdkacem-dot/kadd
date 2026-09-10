import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import '../models/prayer.dart';
import '../services/rug_classifier.dart';
import '../services/rug_verification_policy.dart';
import '../state/app_state.dart';
import '../theme.dart';

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
  final List<DateTime> _captureTimes = <DateTime>[];
  Timer? _captureCooldownTimer;
  bool _initializing = true;
  bool _capturing = false;
  bool _verifying = false;
  DateTime? _nextCaptureAt;
  String? _error;

  bool get _captureCoolingDown =>
      _nextCaptureAt != null && DateTime.now().isBefore(_nextCaptureAt!);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _initializeCameraAndClassifier();
  }

  Future<void> _initializeCameraAndClassifier() async {
    try {
      await _classifier.load();
      if (!_classifier.isLoaded) {
        throw StateError('تعذر تحميل نموذج التحقق على الجهاز');
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('لا توجد كاميرا متاحة على الجهاز');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'تعذر تشغيل التحقق: $error';
      });
    }
  }

  Future<void> _captureStep() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_classifier.isLoaded ||
        _capturing ||
        _verifying ||
        _captureCoolingDown) {
      return;
    }

    setState(() {
      _capturing = true;
      _error = null;
    });
    String? imagePath;
    try {
      final file = await controller.takePicture();
      imagePath = file.path;
      final confidence = await _classifier.classify(file.path);
      if (!mounted) return;

      final capturedAt = DateTime.now();
      setState(() {
        _confidences.add(confidence);
        _captureTimes.add(capturedAt);
        _nextCaptureAt = capturedAt.add(RugVerificationPolicy.minimumCaptureInterval);
      });
      _scheduleCooldownRefresh();

      if (_confidences.length >= RugVerificationPolicy.requiredCaptures) {
        await _finishVerification();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحليل الصورة. حاول مرة أخرى.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التحقق: $error')),
      );
    } finally {
      if (imagePath != null) {
        try {
          await File(imagePath).delete();
        } catch (_) {
          // Best-effort cleanup; images are never intentionally retained.
        }
      }
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _scheduleCooldownRefresh() {
    _captureCooldownTimer?.cancel();
    final next = _nextCaptureAt;
    if (next == null) return;
    final remaining = next.difference(DateTime.now());
    if (remaining <= Duration.zero || !mounted) return;
    _captureCooldownTimer = Timer(remaining, () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _finishVerification() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final passed = RugVerificationPolicy.passes(
        _confidences,
        captureTimes: _captureTimes,
      );
      if (!passed) {
        if (!mounted) return;
        setState(() {
          _confidences.clear();
          _captureTimes.clear();
          _nextCaptureAt = null;
          _verifying = false;
          _error = 'لم ينجح التحقق. التقط الصور الثلاث مع تثبيت السجادة داخل الإطار.';
        });
        _captureCooldownTimer?.cancel();
        return;
      }

      await context.read<AppState>().onRugVerified(widget.prayer);
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'تعذر إكمال فتح القفل. حاول مرة أخرى.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لم يتم فتح القفل: $error')),
      );
    }
  }

  @override
  void dispose() {
    _captureCooldownTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller?.dispose();
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final waiting = _captureCoolingDown;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        appBar: AppBar(
          title: Text('تحقق من سجادة الصلاة', style: AppTextStyles.kufi(size: 16)),
          backgroundColor: AppColors.ink,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  widget.prayer.labelAr,
                  style: AppTextStyles.kufi(size: 22, color: AppColors.unlock),
                ),
                const SizedBox(height: 8),
                Text(
                  'التقط ثلاث صور منفصلة. ثبّت السجادة داخل الإطار وانتظر لحظة بين كل صورة.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(size: 13, color: AppColors.textDim),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _initializing
                        ? const Center(child: CircularProgressIndicator(color: AppColors.unlock))
                        : controller != null && controller.value.isInitialized
                            ? CameraPreview(controller)
                            : Center(
                                child: Text(
                                  _error ?? 'الكاميرا غير متاحة',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body(size: 14, color: AppColors.signal),
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'الصور: ${_confidences.length}/${RugVerificationPolicy.requiredCaptures}',
                  style: AppTextStyles.body(size: 13, color: AppColors.textDim),
                ),
                if (waiting) ...[
                  const SizedBox(height: 6),
                  Text(
                    'انتظر لحظة قبل الصورة التالية…',
                    style: AppTextStyles.body(size: 12, color: AppColors.textDim),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(size: 12, color: AppColors.signal),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _capturing || _verifying || _initializing || waiting ? null : _captureStep,
                    child: Text(
                      _capturing
                          ? 'جارٍ التحليل…'
                          : _verifying
                              ? 'جارٍ التحقق…'
                              : waiting
                                  ? 'انتظر…'
                                  : 'التقاط الصورة',
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
}
