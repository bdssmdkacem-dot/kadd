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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                Center(child: Image.asset('assets/icon/icon.png', width: 92, height: 92, fit: BoxFit.contain)),
                Center(child: Text('${lockedApps.length} تطبيق مقفل الآن', style: AppTextStyles.body(size: 12, color: AppColors.textFaint))),
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
                          Text('كدّ محتاج صلاحية "الوصول للاستخدام"', style: AppTextStyles.kufi(size: 13.5)),
                          const SizedBox(height: 4),
                          Text('بدونها ما يقدرش يعرف أي تطبيق مفتوح حاليًا. فعّل الصلاحية من إعدادات النظام ورجع للتطبيق.', style: AppTextStyles.body(size: 11.5, color: AppColors.textDim)),
                          const SizedBox(height: 10),
                          KaddPrimaryButton(label: 'فتح الإعدادات', padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), onPressed: () => state.requestUsageAccess()),
                        ],
                      ),
                    ),
                  ),
                KaddCard(
                  backgroundColor: AppColors.surface2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: Text(nextPrayer?.name.emoji ?? '🕌', style: const TextStyle(fontSize: 20))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nextPrayer == null ? 'مواقيت الصلاة' : 'الصلاة القادمة: ${nextPrayer.name.labelAr}', style: AppTextStyles.kufi(size: 13.5)),
                        const SizedBox(height: 2),
                        Text(nextPrayer == null ? 'ستتجدد المواقيت تلقائيًا مع بداية اليوم التالي' : '${_countdown(state.timeUntilNextPrayer)} · القفل بعد الأذان بـ ${state.delayMinutesAfterAthan} د', style: AppTextStyles.body(size: 10.8, color: AppColors.textFaint)),
                      ])),
                      if (nextPrayer?.timeToday != null) Text('${nextPrayer!.timeToday!.hour.toString().padLeft(2, '0')}:${nextPrayer.timeToday!.minute.toString().padLeft(2, '0')}', style: AppTextStyles.kufi(size: 14, color: AppColors.unlock)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('تطبيقاتك المقفلة', style: AppTextStyles.kufi(size: 16)),
                const SizedBox(height: 8),
                if (lockedApps.isEmpty)
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppPickerScreen())),
                    child: KaddCard(borderColor: AppColors.unlock.withOpacity(0.4), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add, size: 18, color: AppColors.unlock), const SizedBox(width: 8), Text('ما قفلتي حتى تطبيق — اضغط باش تبدأ', style: AppTextStyles.body(size: 12.5, color: AppColors.unlock))])),
                  )
                else
                  ...lockedApps.map((app) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KaddCard(child: Row(children: [
                          AppIcon(iconBytes: state.iconFor(app.packageName)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(state.displayNameFor(app.packageName), style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600)), Text('${app.repsFor(state.difficulty)} ضغطة = ${app.minutesGranted} د', style: AppTextStyles.body(size: 11, color: AppColors.textFaint))])),
                          KaddPrimaryButton(label: 'ابدأ', padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RepCameraScreen(app: app)))),
                        ])),
                      )),
                const SizedBox(height: 8),
                KaddCard(backgroundColor: AppColors.surface2, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('الدقائق التي كسبتها اليوم', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)), Text('${state.minutesEarnedToday} د', style: AppTextStyles.kufi(size: 16, color: AppColors.unlock))])),
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
