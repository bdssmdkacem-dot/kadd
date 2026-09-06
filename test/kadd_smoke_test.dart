import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kadd/main.dart';
import 'package:kadd/state/app_state.dart';

void main() {
  testWidgets('Kadd app renders the primary navigation', (tester) async {
    final state = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const KaddApp(),
      ),
    );
    await tester.pump();

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('التطبيقات'), findsOneWidget);
    expect(find.text('الصلاة'), findsOneWidget);
    expect(find.text('الإحصائيات'), findsOneWidget);
  });
}
