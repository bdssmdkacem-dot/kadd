import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:kadd/main.dart';
import 'package:kadd/state/app_state.dart';

afterAll(() {});

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('Kadd primary navigation works through real destinations',
      (tester) async {
    final state = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: [Locale('ar')],
          home: RootNav(),
        ),
      ),
    );
    await tester.pump();

    final home = find.widgetWithText(NavigationDestination, 'الرئيسية');
    final prayer = find.widgetWithText(NavigationDestination, 'الصلاة');

    expect(home, findsOneWidget);
    expect(prayer, findsOneWidget);

    await tester.tap(prayer);
    await tester.pump();

    expect(find.text('إعدادات الصلاة'), findsOneWidget);

    await tester.tap(home);
    await tester.pump();

    expect(find.text('كدّ'), findsOneWidget);
  });
}
