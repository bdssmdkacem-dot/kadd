import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/kadd_background.dart';

class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key});

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> with WidgetsBindingObserver {
  String _query = '';
  String? _busyPackage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshApps(showErrors: false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshApps(showErrors: false);
    }
  }

  Future<void> _refreshApps({required bool showErrors}) async {
    final appState = context.read<AppState>();
    try {
      await appState.checkUsageAccess();
      await appState.loadAvailableApps(forceRefresh: true);
    } catch (error) {
      if (!showErrors || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل التطبيقات: $error')),
      );
    }
  }

  Future<void> _openUsageAccessSettings() async {
    await context.read<AppState>().requestUsageAccess();
  }

  Future<void> _setLocked(AppState state, String packageName, bool locked) async {
    if (_busyPackage != null) return;
    setState(() => _busyPackage = packageName);
    try {
      if (!state.hasUsageAccess) {
        await _openUsageAccessSettings();
        return;
      }
      if (locked) {
        await state.addLockedApp(packageName);
      } else {
        await state.removeLockedApp(packageName);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث القفل: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyPackage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lockedPackages = state.apps.map((a) => a.packageName).toSet();
    final filtered = state.availableApps
        .where((a) => a.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: KaddBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_forward, color: AppColors.text),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text('اختر تطبيقًا لتقفله', style: AppTextStyles.kufi(size: 17)),
                      ),
                      if (state.loadingAvailableApps)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.unlock),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppColors.textDim),
                          onPressed: () => _refreshApps(showErrors: true),
                        ),
                    ],
                  ),
                ),
                if (!state.hasUsageAccess)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _openUsageAccessSettings,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.security_outlined, color: AppColors.unlock),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'فعّل صلاحية الوصول إلى بيانات الاستخدام حتى يعمل قفل التطبيقات.',
                                  style: AppTextStyles.body(size: 11.5, color: AppColors.textDim),
                                ),
                              ),
                              const Icon(Icons.arrow_back_ios_new, size: 15, color: AppColors.textFaint),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    style: AppTextStyles.body(size: 13),
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن تطبيق...',
                      hintStyle: AppTextStyles.body(size: 13, color: AppColors.textFaint),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textFaint),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.line),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: !state.loadingAvailableApps && filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.apps_outlined, size: 42, color: AppColors.textFaint),
                                const SizedBox(height: 12),
                                Text(
                                  state.availableApps.isEmpty
                                      ? 'لم تظهر التطبيقات المثبتة بعد — اضغط تحديث بعد تفعيل الصلاحية'
                                      : 'ما لقيتش نتيجة',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body(size: 13, color: AppColors.textFaint),
                                ),
                                if (state.availableApps.isEmpty && state.availableAppsError != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'سبب المشكل: ${state.availableAppsError}',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.body(size: 11, color: AppColors.textDim),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final app = filtered[i];
                            final isLocked = lockedPackages.contains(app.packageName);
                            final isBusy = _busyPackage == app.packageName;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: isBusy ? null : () => _setLocked(state, app.packageName, !isLocked),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      border: Border.all(
                                        color: isLocked ? AppColors.signal : AppColors.line,
                                        width: isLocked ? 1.3 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        AppIcon(iconBytes: app.icon),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            app.name,
                                            style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600),
                                          ),
                                        ),
                                        if (isBusy)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        else
                                          Switch(
                                            value: isLocked,
                                            activeThumbColor: AppColors.signal,
                                            onChanged: (v) => _setLocked(state, app.packageName, v),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
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
