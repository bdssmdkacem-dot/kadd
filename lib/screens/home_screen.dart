import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/effort_ring.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';
import 'app_picker_screen.dart';
import 'rep_camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lockedApps = state.apps.where((a) => a.isEnabled).toList();
    final nextApp = lockedApps.isNotEmpty ? lockedApps.first : null;
    final repsNeeded = nextApp?.repsFor(state.difficulty) ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: KaddBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                RichText(
                  text: TextSpan(children: [
                    TextSpan(text: 'كدّ', style: AppTextStyles.kufi(size: 22, weight: FontWeight.w900)),
                    TextSpan(text: '.', style: AppTextStyles.kufi(size: 22, color: AppColors.signal)),
                  ]),
                ),
                Text('${lockedApps.length} تطبيقات مقفلة الآن',
                    style: AppTextStyles.body(size: 12, color: AppColors.textFaint)),
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
                          Text(
                            'بدونها ما يقدرش يعرف أي تطبيق مفتوح حاليًا، وبالتالي ما يقدرش يقفل شي حاجة. '
                            'غادي يفتح لك إعدادات النظام — فعّل "كدّ" من هناك ورجع للتطبيق.',
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
                const SizedBox(height: 18),
                Center(
                  child: EffortRing(
                    progress: repsNeeded == 0 ? 0 : 0.3, // TODO: live rep progress from camera screen
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(text: '7', style: AppTextStyles.kufi(size: 34)),
                          TextSpan(text: '/$repsNeeded', style: AppTextStyles.kufi(size: 20, color: AppColors.textFaint)),
                        ])),
                        Text('عقلة متبقية', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: KaddPrimaryButton(
                    label: 'ابدأ التمرين',
                    padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
                    onPressed: nextApp == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RepCameraScreen(app: nextApp)),
                            ),
                  ),
                ),
                const SizedBox(height: 20),
                ...lockedApps.map((app) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: KaddCard(
                        child: Row(
                          children: [
                            AppIcon(iconBytes: state.iconFor(app.packageName)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(state.displayNameFor(app.packageName),
                                      style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600)),
                                  Text('${app.repsFor(state.difficulty)} عقلة = ${app.minutesGranted} د',
                                      style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text('🔒 مقفل', style: TextStyle(fontSize: 10, color: AppColors.textFaint)),
                            ),
                          ],
                        ),
                      ),
                    )),
                if (lockedApps.isEmpty)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AppPickerScreen()),
                    ),
                    child: KaddCard(
                      borderColor: AppColors.unlock.withOpacity(0.4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, size: 18, color: AppColors.unlock),
                          const SizedBox(width: 8),
                          Text('ما قفلتي حتى تطبيق — اضغط باش تبدأ', style: AppTextStyles.body(size: 12.5, color: AppColors.unlock)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                KaddCard(
                  backgroundColor: AppColors.surface2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الدقائق التي كسبتها اليوم', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                      Text('${state.minutesEarnedToday} د', style: AppTextStyles.kufi(size: 16, color: AppColors.unlock)),
                    ],
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
