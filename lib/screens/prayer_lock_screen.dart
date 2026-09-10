import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prayer.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';
import 'rug_scan_screen.dart';

/// Shown (via a full-screen native Activity) while a prayer lock is active.
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
                  Text('وقت صلاة ${prayer.labelAr}', style: AppTextStyles.kufi(size: 26)),
                  Text(
                    state.delayMinutesAfterAthan == 0
                        ? 'بدأ القفل مع الأذان — ${state.selectedCity.nameAr}'
                        : 'يبدأ القفل بعد ${state.delayMinutesAfterAthan} دقائق من الأذان — ${state.selectedCity.nameAr}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(size: 12, color: AppColors.textFaint),
                  ),
                  const SizedBox(height: 18),
                  const _PulsingLockBadge(),
                  const SizedBox(height: 14),
                  Text(
                    'تطبيقاتك مقفلة الآن. صوّر سجادة صلاتك للتحقق وفتحها.',
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
                              AppIcon(iconBytes: state.iconFor(app.packageName), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(state.displayNameFor(app.packageName),
                                        style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600)),
                                    Text('مقفل حتى إتمام التحقق', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.lock_outline, color: AppColors.signal, size: 18),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingLockBadge extends StatefulWidget {
  const _PulsingLockBadge();

  @override
  State<_PulsingLockBadge> createState() => _PulsingLockBadgeState();
}

class _PulsingLockBadgeState extends State<_PulsingLockBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.65, end: 1).animate(_controller),
      child: Container(
        width: 74,
        height: 74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.signal, width: 2),
          color: AppColors.signal.withValues(alpha: 0.08),
        ),
        child: const Icon(Icons.lock, color: AppColors.signal, size: 30),
      ),
    );
  }
}
