import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../models/city.dart';
import '../models/prayer.dart';
import '../services/app_usage_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';
import '../widgets/kadd_primary_button.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> with WidgetsBindingObserver {
  final AppUsageService _usageService = AppUsageService();
  bool? _exactAlarmAccess;
  bool _activePrayerLock = false;
  String? _activePrayerName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshNativePrayerState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNativePrayerState();
  }

  Future<void> _refreshNativePrayerState() async {
    try {
      final exact = await _usageService.canScheduleExactAlarms();
      final active = await _usageService.isAthanLockActive();
      final prayer = await _usageService.activePrayerName();
      if (!mounted) return;
      setState(() {
        _exactAlarmAccess = exact;
        _activePrayerLock = active;
        _activePrayerName = prayer;
      });
    } catch (_) {
      if (mounted) setState(() => _exactAlarmAccess = false);
    }
  }

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
                Text('يُقفل التطبيق بعد أذانها، ويُفتح بتصوير السجادة', style: AppTextStyles.body(size: 11.5, color: AppColors.textFaint)),
                const SizedBox(height: 12),
                if (_activePrayerLock)
                  KaddCard(
                    backgroundColor: AppColors.signal.withOpacity(0.12),
                    child: Row(
                      children: [
                        const Text('🔒', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'قفل الصلاة نشط الآن${_activePrayerName == null ? '' : ' — ${_labelFor(_activePrayerName!)}'}',
                            style: AppTextStyles.body(size: 12.5, weight: FontWeight.w700, color: AppColors.signal),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_activePrayerLock) const SizedBox(height: 10),
                if (_exactAlarmAccess == false)
                  KaddCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('السماح بالمنبّهات والتذكيرات مطلوب', style: AppTextStyles.body(size: 13, weight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(
                          'يحتاج Kadd إلى منبّه دقيق حتى يبدأ قفل الصلاة في وقتها حتى عند إغلاق التطبيق أو دخول الهاتف في وضع السكون.',
                          style: AppTextStyles.body(size: 11, color: AppColors.textFaint),
                        ),
                        const SizedBox(height: 10),
                        KaddPrimaryButton(
                          label: 'فتح إعدادات المنبّهات',
                          onPressed: () async {
                            await _usageService.requestExactAlarmAccess();
                            await _refreshNativePrayerState();
                          },
                        ),
                      ],
                    ),
                  ),
                if (_exactAlarmAccess == false) const SizedBox(height: 10),
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
                            Text('اضغط لتغيير المدينة', style: AppTextStyles.body(size: 10.5, color: AppColors.textFaint)),
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
                              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(9)),
                              child: Text(p.name.emoji, style: const TextStyle(fontSize: 15)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name.labelAr, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600)),
                                  Text(p.timeToday != null ? timeFmt.format(p.timeToday!) : '—', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                                ],
                              ),
                            ),
                            Switch(
                              value: p.enabled,
                              activeThumbColor: AppColors.signal,
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
                          SizedBox(width: 52, child: Text('${state.delayMinutesAfterAthan} د', textAlign: TextAlign.center, style: AppTextStyles.kufi(size: 15, color: AppColors.unlock))),
                          _stepperBtn('+', () => state.setDelayMinutes(state.delayMinutesAfterAthan + 1)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                KaddCard(
                  backgroundColor: AppColors.surface2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    state.nextPrayer == null
                        ? 'لا توجد صلاة مفعّلة متبقية اليوم. سيتم استخدام أول صلاة مفعّلة غدًا.'
                        : 'الصلاة القادمة: ${state.nextPrayer!.name.labelAr} — ${timeFmt.format(state.nextPrayer!.timeToday!)}',
                    style: AppTextStyles.body(size: 11.5, color: AppColors.textDim),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _labelFor(String name) {
    final prayer = PrayerName.values.where((item) => item.name == name).firstOrNull;
    return prayer?.labelAr ?? name;
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
                      trailing: state.selectedCity.aladhanName == city.aladhanName ? const Icon(Icons.check, color: AppColors.unlock) : null,
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
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: AppTextStyles.body(size: 14, color: AppColors.textDim)),
      ),
    );
  }
}
