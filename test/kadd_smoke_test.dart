import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:kadd/main.dart';
import 'package:kadd/state/app_state.dart';
import 'package:kadd/screens/home_screen.dart';

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
          locale: Locale('en'),
          supportedLocales: [Locale('en')],
          home: RootNav(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    final navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigationBar.destinations.length, 4);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('التطبيقات'), findsOneWidget);
    expect(find.text('الصلاة'), findsOneWidget);
    expect(find.text('الإحصائيات'), findsOneWidget);
    expect(navigationBar.selectedIndex, 0);

    await tester.tap(find.byIcon(Icons.mosque_outlined));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.text('أي صلاة تريد الالتزام بها؟'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
