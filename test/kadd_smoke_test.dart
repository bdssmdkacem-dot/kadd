import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:kadd/main.dart';
import 'package:kadd/state/app_state.dart';

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
          // Keep MaterialLocalizations on a built-in supported locale. The
          // production RootNav supplies its own Arabic Directionality and
          // labels; this test only needs Material's framework localizations.
          locale: Locale('en'),
          supportedLocales: [Locale('en')],
          home: RootNav(),
        ),
      ),
    );
    await tester.pump();

    final home = find.widgetWithText(NavigationDestination, 'الرئيسية');
    final prayer = find.widgetWithText(NavigationDestination, 'الصلاة');

    expect(home, findsOneWidget);
    expect(prayer, findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await tester.tap(prayer);
    await tester.pump();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.text('أي صلاة تريد الالتزام بها؟'), findsOneWidget);

    await tester.tap(home);
    await tester.pump();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });
}
