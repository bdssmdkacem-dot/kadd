import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/prayer.dart';
import '../services/rug_classifier.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/kadd_primary_button.dart';

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
  bool _initializing = true;
  String? _error;

  static const _confidenceGate = 0.85;

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'تعذر تجهيز التحقق من السجادة';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _verifying || _showSuccess) return;

    setState(() => _verifying = true);
    try {
      final file = await controller.takePicture();
      final confidence = await _classifier.classify(file.path);
      if (!mounted) return;

      setState(() {
        _confidence = confidence;
        _verifying = false;
      });

      if (confidence >= _confidenceGate) {
        HapticFeedback.heavyImpact();
        setState(() => _showSuccess = true);
        await context.read<AppState>().onRugVerified();
        if (!mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.pop(context);
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحليل الصورة. حاول مرة أخرى.')),
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
                          KaddPrimaryButton(label: 'إعادة المحاولة', onPressed: _initialize),
                        ],
                      )
                    : const CircularProgressIndicator(color: AppColors.unlock),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(100)),
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
            if (_controller != null && _controller!.value.isInitialized)
              Center(
                child: Container(
                  width: 220,
                  height: 290,
                  decoration: BoxDecoration(border: Border.all(color: AppColors.unlock, width: 2), borderRadius: BorderRadius.circular(8)),
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
                      style: AppTextStyles.body(size: 12, weight: FontWeight.w600, color: _confidence! >= _confidenceGate ? AppColors.unlock : AppColors.signal),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(12)),
                    child: Text('ضع السجادة كاملة داخل الإطار وثبّت الهاتف حتى تكتمل الدقة', textAlign: TextAlign.center, style: AppTextStyles.body(size: 12.5)),
                  ),
                ],
              ),
            ),
            if (_controller != null && _controller!.value.isInitialized)
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
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _verifying ? AppColors.textFaint : AppColors.signal),
                      child: _verifying
                          ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (_showSuccess)
              Container(
                color: AppColors.ink.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 100, height: 100, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.unlock), child: const Icon(Icons.check, size: 56, color: Color(0xFF1A1F0A))),
                      const SizedBox(height: 16),
                      Text('تقبّل الله 🤲', style: AppTextStyles.kufi(size: 20)),
                      const SizedBox(height: 4),
                      Text('تطبيقاتك فتحت', style: AppTextStyles.body(size: 13, color: AppColors.textDim)),
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
