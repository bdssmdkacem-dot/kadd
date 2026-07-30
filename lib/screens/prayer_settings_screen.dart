import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../models/city.dart';
import '../models/prayer.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';

class PrayerSettingsScreen extends StatelessWidget {
  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final timeFmt = DateFormat('h:mm a', 'ar');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: KaddBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Text('أي صلاة تريد الالتزام بها؟', style: AppTextStyles.kufi(size: 19)),
                Text('يُقفل التطبيق بعد أذانها، ويُفتح بتصوير السجادة',
                    style: AppTextStyles.body(size: 11.5, color: AppColors.textFaint)),
                const SizedBox(height: 12),
                KaddCard(
                  onTap: () => _showCityPicker(context, state),
                  child: Row(
                    children: [
                      const Text('📍', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(state.selectedCity.nameAr, style: AppTextStyles.body(size: 13, weight: FontWeight.w600)),
                            Text('اضغط لتغيير المدينة',
                                style: AppTextStyles.body(size: 10.5, color: AppColors.textFaint)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left, size: 18, color: AppColors.textFaint),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ...state.prayers.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: KaddCard(
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(p.name.emoji, style: const TextStyle(fontSize: 15)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name.labelAr, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600)),
                                  Text(
                                    p.timeToday != null ? timeFmt.format(p.timeToday!) : '—',
                                    style: AppTextStyles.body(size: 11, color: AppColors.textFaint),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: p.enabled,
                              activeColor: AppColors.signal,
                              onChanged: (v) => state.togglePrayer(p, v),
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 6),
                KaddCard(
                  backgroundColor: AppColors.surface2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('القفل يبدأ بعد الأذان بـ', style: AppTextStyles.body(size: 12, color: AppColors.textDim)),
                      Row(
                        children: [
                          _stepperBtn('−', () => state.setDelayMinutes(state.delayMinutesAfterAthan - 1)),
                          SizedBox(
                            width: 52,
                            child: Text('${state.delayMinutesAfterAthan} د',
                                textAlign: TextAlign.center, style: AppTextStyles.kufi(size: 15, color: AppColors.unlock)),
                          ),
                          _stepperBtn('+', () => state.setDelayMinutes(state.delayMinutesAfterAthan + 1)),
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

  void _showCityPicker(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('اختر مدينتك', style: AppTextStyles.kufi(size: 16)),
                const SizedBox(height: 8),
                ...moroccanCities.map((city) => ListTile(
                      title: Text(city.nameAr, style: AppTextStyles.body(size: 14)),
                      trailing: state.selectedCity.aladhanName == city.aladhanName
                          ? const Icon(Icons.check, color: AppColors.unlock)
                          : null,
                      onTap: () {
                        state.setCity(city);
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepperBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: AppTextStyles.body(size: 14, color: AppColors.textDim)),
      ),
    );
  }
}
