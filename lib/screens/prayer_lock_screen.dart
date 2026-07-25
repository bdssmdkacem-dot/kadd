import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prayer.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';
import 'rug_scan_screen.dart';

/// Shown (via a full-screen native Activity, see android_additions/) when a
/// locked app is foregrounded during an active post-Athan lock window.
class PrayerLockScreen extends StatelessWidget {
  final PrayerName prayer;
  const PrayerLockScreen({super.key, required this.prayer});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lockedApps = state.apps.where((a) => a.isEnabled).take(2).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: KaddBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(prayer.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 6),
                  Text('أذان ${prayer.labelAr}', style: AppTextStyles.kufi(size: 26)),
                  Text('أُذّن قبل ${state.delayMinutesAfterAthan} دقائق — ${state.cityLabel}',
                      style: AppTextStyles.body(size: 12, color: AppColors.textFaint)),
                  const SizedBox(height: 18),
                  const _PulsingLockBadge(),
                  const SizedBox(height: 14),
                  Text(
                    'تطبيقاتك مقفلة الآن. صوّر سجادة صلاتك لتفتحها.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(size: 12.5, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 16),
                  KaddPrimaryButton(
                    label: 'صوّر السجادة الآن',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RugScanScreen(prayer: prayer)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...lockedApps.map((app) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KaddCard(
                          child: Row(
                            children: [
                              Text(app.emoji, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(app.nameAr, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600)),
                                    Text('مقفل حتى التحقق', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                                  ],
                                ),
                              ),
                              const Text('🔒'),
                            ],
                          ),
                        ),
                      )),
                  KaddCard(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'سيُفتح كل شيء تلقائيًا بمجرد التعرف على السجادة، بلا عقلات هذه المرة',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(size: 11, color: AppColors.textFaint),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slow, subtle breathing pulse on the lock icon — signals "waiting on
/// you" without being distracting. This kind of small continuous motion is
/// what separated Aqim's hand-finished feel from a static mockup screenshot.
class _PulsingLockBadge extends StatefulWidget {
  const _PulsingLockBadge();

  @override
  State<_PulsingLockBadge> createState() => _PulsingLockBadgeState();
}

class _PulsingLockBadgeState extends State<_PulsingLockBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.signal, width: 2),
        ),
        child: const Text('🔒', style: TextStyle(fontSize: 40)),
      ),
    );
  }
}
