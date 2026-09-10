import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const _dayLabels = ['أحد', 'اثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.appUsageHistory.entries.toList()
      ..sort((a, b) {
        final unlocks = b.value.unlocks.compareTo(a.value.unlocks);
        return unlocks != 0 ? unlocks : b.value.minutes.compareTo(a.value.minutes);
      });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: KaddBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Text('أسبوعك بالأرقام', style: AppTextStyles.kufi(size: 19)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final done = state.last7Days[i];
                    return Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: done ? AppColors.unlock : AppColors.surface2,
                            border: Border.all(color: done ? AppColors.unlock : AppColors.line),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            done ? '✓' : '-',
                            style: TextStyle(fontSize: 11, color: done ? const Color(0xFF1A1F0A) : AppColors.textFaint),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_dayLabels[i], style: AppTextStyles.body(size: 10, color: AppColors.textFaint)),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 16),
                KaddCard(
                  backgroundColor: AppColors.surface2,
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        Text('${state.repsThisWeek}', style: AppTextStyles.kufi(size: 40, color: AppColors.unlock)),
                        const SizedBox(height: 6),
                        Text('تكرارًا كدّيتها هذا الأسبوع', style: AppTextStyles.body(size: 12, color: AppColors.textDim)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _miniStat('${state.minutesEarnedToday} د', 'وقت الشاشة اليوم')),
                    const SizedBox(width: 10),
                    Expanded(child: _miniStat('${state.streakDays}', 'أيام الالتزام المتتالية')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _miniStat('${state.totalReps}', 'إجمالي التكرارات')),
                    const SizedBox(width: 10),
                    Expanded(child: _miniStat('${state.totalMinutesEarned} د', 'إجمالي الدقائق المكتسبة')),
                  ],
                ),
                const SizedBox(height: 10),
                KaddCard(
                  backgroundColor: AppColors.surface2,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('🕌', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${state.prayerUnlocks}', style: AppTextStyles.kufi(size: 16)),
                            Text('مرات فتح بعد التحقق من السجادة', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('حسب التطبيق', style: AppTextStyles.kufi(size: 16)),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  KaddCard(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'لا توجد عمليات فتح مسجلة بعد. عند نجاح التحقق بالتمارين سيظهر سجل كل تطبيق هنا.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(size: 12, color: AppColors.textFaint),
                    ),
                  )
                else
                  ...history.map((entry) => _appHistoryTile(state, entry.key, entry.value)),
                const SizedBox(height: 10),
                KaddCard(
                  backgroundColor: AppColors.signal.withOpacity(0.08),
                  borderColor: AppColors.signal.withOpacity(0.25),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${state.streakDays} أيام متتالية', style: AppTextStyles.kufi(size: 14)),
                          Text('استمر ولا تفوّت يومًا', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                        ],
                      ),
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

  Widget _appHistoryTile(AppState state, String packageName, AppUsageSummary summary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KaddCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _appIcon(state, packageName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.displayNameFor(packageName), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.kufi(size: 13)),
                  const SizedBox(height: 3),
                  Text('${summary.unlocks} فتحات • ${summary.reps} تكرار • ${summary.minutes} د',
                      style: AppTextStyles.body(size: 10.5, color: AppColors.textFaint)),
                ],
              ),
            ),
            if (summary.lastUnlockDate != null)
              Text(summary.lastUnlockDate!, style: AppTextStyles.body(size: 9, color: AppColors.textFaint)),
          ],
        ),
      ),
    );
  }

  Widget _appIcon(AppState state, String packageName) {
    final bytes = state.iconFor(packageName);
    if (bytes == null) {
      return const CircleAvatar(radius: 20, child: Icon(Icons.apps, size: 20));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }

  Widget _miniStat(String value, String label) {
    return KaddCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.kufi(size: 16)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: AppTextStyles.body(size: 10.5, color: AppColors.textFaint)),
        ],
      ),
    );
  }
}
