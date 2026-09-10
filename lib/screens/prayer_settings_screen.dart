import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prayer.dart';
import '../services/app_usage_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/kadd_card.dart';
import '../widgets/kadd_background.dart';
import '../models/city.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> with WidgetsBindingObserver {
  final AppUsageService _usageService = AppUsageService();
  bool? _exactAlarmAccess;
  bool _loadingNativeState = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshNativePrayerState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNativePrayerState();
    }
  }

  Future<void> _refreshNativePrayerState() async {
    try {
      final exact = await _usageService.canScheduleExactAlarms();
      if (!mounted) return;
      setState(() {
        _exactAlarmAccess = exact;
        _loadingNativeState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exactAlarmAccess = null;
        _loadingNativeState = false;
      });
    }
  }

  Future<void> _requestExactAlarmAccess() async {
    await _usageService.requestExactAlarmAccess();
    if (!mounted) return;
    await _refreshNativePrayerState();
    if (!mounted || _exactAlarmAccess != true) return;
    await context.read<AppState>().refreshPrayerTimes();
  }

  Future<void> _showCityPicker(BuildContext context, AppState state) async {
    final selected = await showModalBottomSheet<MoroccanCity>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final city in moroccanCities)
              ListTile(
                title: Text(city.nameAr, style: AppTextStyles.body(size: 14)),
                trailing: city.aladhanName == state.selectedCity.aladhanName
                    ? const Icon(Icons.check, color: AppColors.unlock)
                    : null,
                onTap: () => Navigator.pop(sheetContext, city),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    await state.setCity(selected);
  }

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
              padding: const EdgeInsets.all(20),
              children: [
                Text('إعدادات الصلاة', style: AppTextStyles.kufi(size: 20)),
                const SizedBox(height: 16),
                KaddCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('المنبّهات الدقيقة', style: AppTextStyles.body(size: 14, weight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text('يحتاج Kadd إلى منبّه دقيق حتى يبدأ قفل الصلاة في وقته، حتى عند إغلاق التطبيق أو دخول الهاتف في وضع السكون.', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                      const SizedBox(height: 10),
                      if (_loadingNativeState)
                        const Center(child: CircularProgressIndicator())
                      else if (_exactAlarmAccess == false)
                        KaddPrimaryButton(label: 'فتح إعدادات المنبّهات', onPressed: _requestExactAlarmAccess)
                      else
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppColors.unlock),
                            const SizedBox(width: 8),
                            Expanded(child: Text('الوصول إلى المنبّهات الدقيقة مفعّل.', style: AppTextStyles.body(size: 12))),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                KaddCard(
                  onTap: () => _showCityPicker(context, state),
                  child: Row(
                    children: [
                      const Text('📍', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.selectedCity.nameAr, style: AppTextStyles.body(size: 13))),
                      const Icon(Icons.chevron_left, color: AppColors.textFaint),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                KaddCard(
                  child: Column(
                    children: [
                      for (final prayer in state.prayers)
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${prayer.name.emoji}  ${prayer.name.labelAr}', style: AppTextStyles.body(size: 13)),
                          subtitle: prayer.timeToday == null ? null : Text(_formatTime(prayer.timeToday!), style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                          value: prayer.enabled,
                          onChanged: (value) => state.togglePrayer(prayer, value),
                          activeThumbColor: AppColors.unlock,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                KaddCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('مدة الانتظار بعد الأذان', style: AppTextStyles.body(size: 13, weight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('${state.delayMinutesAfterAthan} دقيقة', style: AppTextStyles.kufi(size: 16, color: AppColors.unlock)),
                      Slider(
                        value: state.delayMinutesAfterAthan.toDouble(),
                        min: 0,
                        max: 60,
                        divisions: 12,
                        label: '${state.delayMinutesAfterAthan}',
                        onChanged: (value) => state.setDelayMinutes(value.round()),
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

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
