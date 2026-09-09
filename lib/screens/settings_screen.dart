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

  Future<void> _configureApp(BuildContext context, LockedApp app) async {
    final repsController = TextEditingController(text: app.baseReps.toString());
    final minutesController = TextEditingController(text: app.minutesGranted.toString());
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('إعداد ${context.read<AppState>().displayNameFor(app.packageName)}', style: AppTextStyles.kufi(size: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: repsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(labelText: 'التكرارات الأساسية', helperText: 'من 1 إلى 500'),
                validator: (value) {
                  final n = int.tryParse(value ?? '');
                  return n == null || n < 1 || n > 500 ? 'أدخل رقمًا بين 1 و500' : null;
                },
              ),
              TextFormField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(labelText: 'دقائق الفتح', helperText: 'من 1 إلى 180 دقيقة'),
                validator: (value) {
                  final n = int.tryParse(value ?? '');
                  return n == null || n < 1 || n > 180 ? 'أدخل رقمًا بين 1 و180' : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await context.read<AppState>().updateLockedAppConfig(
                    app,
                    reps: int.parse(repsController.text),
                    minutes: int.parse(minutesController.text),
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    repsController.dispose();
    minutesController.dispose();
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Text('ما الذي يستحق كدّك؟', style: AppTextStyles.kufi(size: 19)),
                Text('اختر التطبيقات وحدد مقدار المجهود ومدة الفتح', style: AppTextStyles.body(size: 11.5, color: AppColors.textFaint)),
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
                          child: Text(d.labelAr, style: AppTextStyles.body(size: 12, weight: FontWeight.w600, color: active ? const Color(0xFF1A0D08) : AppColors.textDim)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (state.apps.isEmpty)
                  KaddCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Text('لم تختر أي تطبيق بعد', style: AppTextStyles.body(size: 13, color: AppColors.textDim)),
                      const SizedBox(height: 4),
                      Text('أضف التطبيقات التي تريد أن يصبح فتحها قرارًا واعيًا', style: AppTextStyles.body(size: 11.5, color: AppColors.textFaint)),
                    ]),
                  )
                else
                  ...state.apps.map((app) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KaddCard(
                          child: InkWell(
                            onTap: () => _configureApp(context, app),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  AppIcon(iconBytes: state.iconFor(app.packageName)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(state.displayNameFor(app.packageName), style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600)),
                                        Text('${app.repsFor(state.difficulty)} تكرار ← ${app.minutesGranted} د', style: AppTextStyles.body(size: 11, color: AppColors.textFaint)),
                                      ],
                                    ),
                                  ),
                                  Switch(value: app.isEnabled, activeColor: AppColors.signal, onChanged: (v) => state.toggleApp(app, v)),
                                  IconButton(icon: const Icon(Icons.tune, size: 18, color: AppColors.textFaint), onPressed: () => _configureApp(context, app)),
                                  IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.textFaint), onPressed: () => state.removeLockedApp(app.packageName)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppPickerScreen())),
                  child: KaddCard(
                    borderColor: AppColors.unlock.withOpacity(0.4),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add, size: 18, color: AppColors.unlock),
                      const SizedBox(width: 8),
                      Text('إضافة تطبيق', style: AppTextStyles.kufi(size: 13, color: AppColors.unlock)),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                KaddCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('صلاحية مراقبة الاستخدام', style: AppTextStyles.kufi(size: 13)),
                    const SizedBox(height: 5),
                    Text(state.hasUsageAccess ? 'مفعلة — يستطيع كدّ معرفة التطبيق المفتوح' : 'غير مفعلة — القفل لن يعمل حتى تمنح الصلاحية', style: AppTextStyles.body(size: 11.5, color: state.hasUsageAccess ? AppColors.unlock : AppColors.signal)),
                    const SizedBox(height: 10),
                    KaddPrimaryButton(label: state.hasUsageAccess ? 'إعادة التحقق' : 'فتح إعدادات الاستخدام', padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), onPressed: () async {
                      if (!state.hasUsageAccess) await state.requestUsageAccess();
                      await state.checkUsageAccess();
                    }),
                  ]),
                ),
                const SizedBox(height: 12),
                KaddCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restart_alt, color: AppColors.signal),
                    title: Text('إعادة ضبط بيانات كدّ', style: AppTextStyles.body(size: 13.5)),
                    subtitle: Text('يحذف التطبيقات المقفلة والإحصائيات والإعدادات المحلية', style: AppTextStyles.body(size: 10.5, color: AppColors.textFaint)),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(backgroundColor: AppColors.surface, title: const Text('تأكيد إعادة الضبط'), content: const Text('سيتم حذف كل بيانات كدّ المحلية. هل تريد المتابعة؟'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إعادة الضبط'))])) ?? false;
                      if (confirmed && context.mounted) await context.read<AppState>().resetAllData();
                    },
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
