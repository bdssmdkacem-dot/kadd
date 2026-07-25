import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/locked_app.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: KaddBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Text('ما الذي يستحق كدّك؟', style: AppTextStyles.kufi(size: 19)),
                Text('فعّل القفل على التطبيقات التي تسرق وقتك',
                    style: AppTextStyles.body(size: 11.5, color: AppColors.textFaint)),
                const SizedBox(height: 14),
                Row(
                  children: Difficulty.values.map((d) {
                    final active = state.difficulty == d;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => state.setDifficulty(d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: active ? AppColors.signal : Colors.transparent,
                            border: Border.all(color: active ? AppColors.signal : AppColors.line),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            d.labelAr,
                            style: AppTextStyles.body(
                              size: 12,
                              weight: FontWeight.w600,
                              color: active ? const Color(0xFF1A0D08) : AppColors.textDim,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                ...state.apps.map((app) => Padding(
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
                                  Text(
                                    app.baseReps == 0
                                        ? 'غير مقفل'
                                        : '${app.repsFor(state.difficulty)} عقلة لكل ${app.minutesGranted} د',
                                    style: AppTextStyles.body(size: 11, color: AppColors.textFaint),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: app.isEnabled,
                              activeColor: AppColors.signal,
                              onChanged: app.baseReps == 0 ? null : (v) => state.toggleApp(app, v),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
