import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:kadd/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first-run app picker selects an app and continues to settings', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    Future<void> waitFor(Finder finder, {Duration timeout = const Duration(seconds: 35)}) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (finder.evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 500));
      }
      throw TestFailure('Timed out waiting for $finder');
    }

    await waitFor(find.text('ابدأ باختيار التطبيقات'));
    await waitFor(find.textContaining('تطبيقًا متاحًا'));

    final firstApp = find.bySemanticsLabel(RegExp(r'^قفل .+')).first;
    await waitFor(firstApp);
    await tester.ensureVisible(firstApp);
    await tester.tap(firstApp);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final continueText = find.text('متابعة إلى الإعدادات');
    await waitFor(continueText);

    final continueButton = find.ancestor(
      of: continueText,
      matching: find.byType(ElevatedButton),
    );
    expect(continueButton, findsOneWidget);
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNotNull);

    await tester.tap(continueButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('ابدأ باختيار التطبيقات'), findsNothing);
  });
}
