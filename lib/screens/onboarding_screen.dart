import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/kadd_background.dart';
import '../widgets/kadd_card.dart';
import 'app_picker_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _items = <_IntroItem>[
    _IntroItem(Icons.lock_outline, 'أنت من يحدد ما تريد تقليله', 'اختر التطبيقات التي تريد أن تتوقف عن فتحها بشكل تلقائي ومندفع.'),
    _IntroItem(Icons.directions_run, 'الوصول يحتاج مجهودًا', 'عندما تحاول فتح تطبيق مقفل، ينقلك كدّ إلى جلسة تمرين. عند إكمال الهدف تحصل على وقت فتح مؤقت.'),
    _IntroItem(Icons.security_outlined, 'صلاحيات واضحة لوظائف محددة', 'وصول الاستخدام مطلوب لاكتشاف التطبيق المفتوح وتشغيل القفل. الكاميرا تُطلب فقط أثناء التمرين أو التحقق من السجادة، والمنبّهات الدقيقة تُستخدم فقط لقفل الصلاة في وقته.'),
    _IntroItem(Icons.shield_outlined, 'المعالجة الأساسية محلية', 'قائمة التطبيقات، بيانات الاستخدام، صور الكاميرا وبيانات الحركة تُستخدم على الجهاز لتشغيل وظائف كدّ. كدّ لا يرفع هذه البيانات إلى خادم تابع له.'),
    _IntroItem(Icons.tune, 'يمكنك تغيير كل شيء لاحقًا', 'بعد البداية يمكنك تعديل التطبيقات، الصعوبة، أوقات الصلاة والإعدادات. ابدأ باختيار التطبيقات التي تريد قفلها.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await context.read<AppState>().completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppPickerScreen()),
    );
  }

  void _next() {
    if (_page == _items.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: KaddBackground(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _items.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/icon/icon.png', width: 96, height: 96),
                            const SizedBox(height: 22),
                            Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surface2,
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Icon(item.icon, size: 34, color: AppColors.unlock),
                            ),
                            const SizedBox(height: 22),
                            Text(item.title, textAlign: TextAlign.center, style: AppTextStyles.kufi(size: 23)),
                            const SizedBox(height: 12),
                            KaddCard(
                              padding: const EdgeInsets.all(16),
                              child: Text(item.body, textAlign: TextAlign.center, style: AppTextStyles.body(size: 13.5, color: AppColors.textDim)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _items.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _page ? 24 : 7,
                      height: 7,
                      decoration: BoxDecoration(color: index == _page ? AppColors.unlock : AppColors.line, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                  child: Column(
                    children: [
                      KaddPrimaryButton(label: _page == _items.length - 1 ? 'ابدأ واختر التطبيقات' : 'التالي', onPressed: _next),
                      if (_page < _items.length - 1)
                        TextButton(onPressed: _finish, child: Text('تخطي', style: AppTextStyles.body(size: 12, color: AppColors.textFaint))),
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
}

class _IntroItem {
  final IconData icon;
  final String title;
  final String body;
  const _IntroItem(this.icon, this.title, this.body);
}
