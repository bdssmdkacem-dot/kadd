import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/premium_service.dart';
import '../theme.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumService>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('كدّ Premium')),
        body: KaddBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                KaddCard(
                  borderColor: AppColors.unlock.withOpacity(0.55),
                  child: Column(
                    children: [
                      const Icon(Icons.workspace_premium, size: 56, color: AppColors.unlock),
                      const SizedBox(height: 12),
                      Text(
                        premium.isPremium ? 'Premium مفعّل' : 'اجعل كدّ أقوى',
                        style: AppTextStyles.kufi(size: 20),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        premium.isPremium
                            ? 'الإعلانات متوقفة، ويمكن توسيع مزايا Premium مستقبلاً دون المساس بالقفل الأساسي.'
                            : 'نسخة Premium مصممة لإزالة الإعلانات وإضافة مزايا متقدمة تدريجياً.',
                        style: AppTextStyles.body(size: 12, color: AppColors.textDim),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      const _PremiumFeature(label: 'بدون إعلانات'),
                      const _PremiumFeature(label: 'مزايا قفل متقدمة — تضاف تدريجياً'),
                      const _PremiumFeature(label: 'إحصائيات وتخصيصات متقدمة — تضاف تدريجياً'),
                      const SizedBox(height: 18),
                      if (premium.isPremium)
                        Text('اشتراكك مستعاد من Google Play.', style: AppTextStyles.body(size: 12, color: AppColors.unlock))
                      else ...[
                        if (premium.monthlyProduct != null)
                          Text(
                            premium.monthlyProduct!.price,
                            style: AppTextStyles.kufi(size: 18, color: AppColors.unlock),
                          ),
                        const SizedBox(height: 10),
                        KaddPrimaryButton(
                          label: premium.loading ? 'جارٍ المعالجة…' : 'اشترك في Premium',
                          onPressed: premium.loading ? null : premium.buyPremium,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: premium.loading ? null : premium.restorePurchases,
                          child: const Text('استعادة الاشتراك'),
                        ),
                      ],
                      if (premium.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          premium.error!,
                          style: AppTextStyles.body(size: 11, color: AppColors.signal),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'سيظل الإصدار المجاني يعمل حتى إذا لم يتوفر Google Play Billing. لا يتم منح Premium محلياً بدون إثبات شراء من المتجر.',
                  style: AppTextStyles.body(size: 10.5, color: AppColors.textFaint),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumFeature extends StatelessWidget {
  final String label;
  const _PremiumFeature({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.unlock),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.body(size: 12))),
        ],
      ),
    );
  }
}
