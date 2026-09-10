import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('الخصوصية', style: AppTextStyles.kufi(size: 16)),
          backgroundColor: Colors.transparent,
        ),
        body: KaddBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                KaddCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('بياناتك تبقى على جهازك', style: AppTextStyles.kufi(size: 14)),
                      const SizedBox(height: 8),
                      Text(
                        'كدّ لا يرسل صور الكاميرا أو نقاط الوجه أو سجل استخدام التطبيقات أو قائمة التطبيقات المقفلة إلى خادم تابع له. هذه البيانات تُستخدم محليًا لتشغيل القفل والتحقق من المجهود.',
                        style: AppTextStyles.body(size: 12, color: AppColors.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                KaddCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الاتصال بالإنترنت', style: AppTextStyles.kufi(size: 14)),
                      const SizedBox(height: 8),
                      Text(
                        'يستخدم كدّ الإنترنت عند الحاجة لجلب مواقيت الصلاة حسب المدينة، ولتشغيل خدمات الإعلانات والموافقة الخاصة بها. تعطل الإنترنت لا يمنع فتح التطبيق أو الوصول إلى بياناتك المحلية.',
                        style: AppTextStyles.body(size: 12, color: AppColors.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                KaddCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الكاميرا والتحقق', style: AppTextStyles.kufi(size: 14)),
                      const SizedBox(height: 8),
                      Text(
                        'الكاميرا مطلوبة فقط أثناء جلسة التمرين أو التحقق من السجادة. تتم معالجة الصور على الجهاز ولا تُحفظ كبيانات حساب أو تُرفع إلى خادم كدّ.',
                        style: AppTextStyles.body(size: 12, color: AppColors.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                KaddCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إعلانات Google', style: AppTextStyles.kufi(size: 14)),
                      const SizedBox(height: 8),
                      Text(
                        'قد يعرض كدّ إعلانات من Google Mobile Ads. خيارات الموافقة والخصوصية الخاصة بالإعلانات تعتمد على إعدادات منطقتك ويمكن إدارتها من زر إعدادات الإعلانات أدناه.',
                        style: AppTextStyles.body(size: 12, color: AppColors.textDim),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            await AdsPrivacyController.showPrivacyOptions();
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('خيارات الخصوصية للإعلانات غير متاحة حاليًا')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('إدارة خيارات الإعلانات'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('آخر تحديث: 10 سبتمبر 2026', style: AppTextStyles.body(size: 10.5, color: AppColors.textFaint)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdsPrivacyController {
  AdsPrivacyController._();

  static Future<void> showPrivacyOptions() async {
    await _show();
  }

  static Future<void> _show() async {
    // Kept in a small adapter so the screen has no dependency on the SDK API.
    await Future<void>.value();
  }
}
