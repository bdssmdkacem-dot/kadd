import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/prayer.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';
import 'app_picker_screen.dart';
import 'rep_camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _countdown(Duration? duration) {
    if (duration == null) return 'جاري تحميل مواقيت الصلاة…';
    final totalMinutes = duration.inMinutes.clamp(0, 24 * 60);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) return 'بعد $hours س و$minutes د';
    return 'بعد $minutes د';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lockedApps = state.apps.where((a) => a.isEnabled).toList();
    final nextPrayer = state.nextPrayer;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: KaddBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Image.asset('assets/icon/icon.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('كدّ', style: AppTextStyles.kufi(size: 21)),
                          const SizedBox(height: 1),
                          Text(
                            '${lockedApps.length} تطبيق ${lockedApps.length == 1 ? 'مقفل' : 'مقفلة'} الآن',
                            style: AppTextStyles.body(size: 11, color: AppColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.lock_outline_rounded, color: AppColors.signal, size: 22),
                  ],
                ),
                const SizedBox(height: 18),

                KaddCard(
                  backgroundColor: AppColors.surface2,
                  borderColor: AppColors.unlock.withOpacity(0.24),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('كدّك اليوم', style: AppTextStyles.kufi(size: 14)),
                            const SizedBox(height: 5),
                            Text(
                              '${state.minutesEarnedToday} د',
                              style: AppTextStyles.kufi(size: 31, color: AppColors.unlock),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'الدقائق التي كسبتها بجهدك',
                              style: AppTextStyles.body(size: 11, color: AppColors.textDim),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.unlock.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: AppColors.unlock, size: 26),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (!state.hasUsageAccess)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: KaddCard(
                      backgroundColor: AppColors.signal.withOpacity(0.1),
                      borderColor: AppColors.signal.withOpacity(0.35),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.signal, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'فعّل صلاحية الوصول للاستخدام',
                                  style: AppTextStyles.kufi(size: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'بدونها ما يقدرش كدّ يعرف أي تطبيق مفتوح حاليًا.',
                            style: AppTextStyles.body(size: 11.5, color: AppColors.textDim),
                          ),
                          const SizedBox(height: 10),
                          KaddPrimaryButton(
                            label: 'فتح الإعدادات',
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            onPressed: () => state.requestUsageAccess(),
                          ),
                        ],
                      ),
                    ),
                  ),

                KaddCard(
                  backgroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(nextPrayer?.name.emoji ?? '🕌', style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nextPrayer == null ? 'مواقيت الصلاة' : 'الصلاة القادمة: ${nextPrayer.name.labelAr}',
                              style: AppTextStyles.kufi(size: 13.2),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              nextPrayer == null
                                  ? 'ستتجدد المواقيت تلقائيًا مع بداية اليوم التالي'
                                  : '${_countdown(state.timeUntilNextPrayer)} · القفل بعد الأذان بـ ${state.delayMinutesAfterAthan} د',
                              style: AppTextStyles.body(size: 10.7, color: AppColors.textFaint),
                            ),
                          ],
                        ),
                      ),
                      if (nextPrayer?.timeToday != null)
                        Text(
                          '${nextPrayer!.timeToday!.hour.toString().padLeft(2, '0')}:${nextPrayer.timeToday!.minute.toString().padLeft(2, '0')}',
                          style: AppTextStyles.kufi(size: 13.5, color: AppColors.unlock),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(child: Text('تطبيقاتك المقفلة', style: AppTextStyles.kufi(size: 17))),
                    Text('${lockedApps.length}', style: AppTextStyles.kufi(size: 13, color: AppColors.textFaint)),
                  ],
                ),
                const SizedBox(height: 9),

                if (lockedApps.isEmpty)
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppPickerScreen())),
                    child: KaddCard(
                      borderColor: AppColors.unlock.withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded, size: 19, color: AppColors.unlock),
                          const SizedBox(width: 8),
                          Text('أضف أول تطبيق وابدأ', style: AppTextStyles.body(size: 12.5, color: AppColors.unlock)),
                        ],
                      ),
                    ),
                  )
                else
                  ...lockedApps.map(
                    (app) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: KaddCard(
                        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                        child: Row(
                          children: [
                            AppIcon(iconBytes: state.iconFor(app.packageName)),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.displayNameFor(app.packageName),
                                    style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${app.repsFor(state.difficulty)} ضغطة = ${app.minutesGranted} د',
                                    style: AppTextStyles.body(size: 10.8, color: AppColors.textFaint),
                                  ),
                                ],
                              ),
                            ),
                            KaddPrimaryButton(
                              label: 'ابدأ',
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => RepCameraScreen(app: app)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
                Center(child: Text('كل دقيقة تكسبها = وقت تستحقه', style: AppTextStyles.body(size: 11, color: AppColors.textFaint))),
                const SizedBox(height: 16),
                const Center(child: BannerAdWidget()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
