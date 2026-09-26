import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:kadd/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first-run app picker can select an app and continue', (tester) async {
    app.main();

    await tester.pumpAndSettle(const Duration(seconds: 2));

    Future<void> waitFor(Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (finder.evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 500));
      }
      throw TestFailure('Timed out waiting for $finder');
    }

    await waitFor(find.text('ابدأ باختيار التطبيقات'));
    await waitFor(find.textContaining('تطبيقًا متاحًا'));

    final firstRow = find.byKey(
      const ValueKey('kadd-app-row-com.com.android.settings'),
    );

    Finder appRow = firstRow;
    if (firstRow.evaluate().isEmpty) {
      appRow = find.byKey(const ValueKey('kadd-app-row-com.android.settings'));
    }
    if (appRow.evaluate().isEmpty) {
      appRow = find.bySemanticsLabel(RegExp(r'^قفل .+')).first;
    }

    await waitFor(appRow);
    await tester.ensureVisible(appRow);
    await tester.tap(appRow);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final continueButton = find.text('متابعة إلى الإعدادات');
    await waitFor(continueButton);

    final buttonWidget = tester.widget<Text>(continueButton);
    expect(buttonWidget.data, 'متابعة إلى الإعدادات');

    final state = tester.state(find.byType(app.KaddApp));
    expect(state, isNotNull);
  });
}
