import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/locked_app.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';
import 'app_picker_screen.dart';

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
                Text('اختر من تطبيقاتك المثبتة أيها يستحق القفل',
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
                const SizedBox(height: 16),
                if (state.apps.isEmpty)
                  KaddCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('ما قفلتي حتى تطبيق بعد', style: AppTextStyles.body(size: 13, color: AppColors.textDim)),
                        const SizedBox(height: 4),
                        Text('اضغط "إضافة تطبيق" باش تختار من تطبيقاتك',
                            style: AppTextStyles.body(size: 11.5, color: AppColors.textFaint)),
                      ],
                    ),
                  )
                else
                  ...state.apps.map((app) => Padding(
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
                                    Text(
                                      '${app.repsFor(state.difficulty)} ضغطة لكل ${app.minutesGranted} د',
                                      style: AppTextStyles.body(size: 11, color: AppColors.textFaint),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: app.isEnabled,
                                activeColor: AppColors.signal,
                                onChanged: (v) => state.toggleApp(app, v),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.textFaint),
                                onPressed: () => state.removeLockedApp(app.packageName),
                              ),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 8),
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
                        Text('إضافة تطبيق', style: AppTextStyles.kufi(size: 13, color: AppColors.unlock)),
                      ],
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
