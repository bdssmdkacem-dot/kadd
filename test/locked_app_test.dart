import 'package:flutter_test/flutter_test.dart';
import 'package:kadd/models/locked_app.dart';

void main() {
  group('LockedApp configuration', () {
    test('uses safe defaults', () {
      final app = LockedApp(packageName: 'com.example.app');

      expect(app.packageName, 'com.example.app');
      expect(app.baseReps, 20);
      expect(app.minutesGranted, 15);
      expect(app.isEnabled, isTrue);
    });

    test('clamps constructor values to supported limits', () {
      final low = LockedApp(
        packageName: 'com.example.low',
        baseReps: -20,
        minutesGranted: 0,
      );
      final high = LockedApp(
        packageName: 'com.example.high',
        baseReps: 9999,
        minutesGranted: 9999,
      );

      expect(low.baseReps, 1);
      expect(low.minutesGranted, 1);
      expect(high.baseReps, 500);
      expect(high.minutesGranted, 180);
    });

    test('configure keeps values inside supported limits', () {
      final app = LockedApp(packageName: 'com.example.app');

      app.configure(reps: 0, minutes: 999);
      expect(app.baseReps, 1);
      expect(app.minutesGranted, 180);

      app.configure(reps: 75, minutes: 30);
      expect(app.baseReps, 75);
      expect(app.minutesGranted, 30);
    });
  });

  group('LockedApp difficulty', () {
    test('calculates exercise reps deterministically', () {
      final app = LockedApp(packageName: 'com.example.app', baseReps: 20);

      expect(app.repsFor(Difficulty.easy), 12);
      expect(app.repsFor(Difficulty.medium), 20);
      expect(app.repsFor(Difficulty.hard), 32);
    });

    test('caps difficulty result at the maximum', () {
      final app = LockedApp(packageName: 'com.example.app', baseReps: 500);

      expect(app.repsFor(Difficulty.hard), 500);
    });
  });

  group('LockedApp persistence', () {
    test('round-trips JSON without losing configuration', () {
      final original = LockedApp(
        packageName: 'com.example.app',
        baseReps: 42,
        minutesGranted: 25,
        isEnabled: false,
      );

      final restored = LockedApp.fromJson(original.toJson());

      expect(restored.packageName, 'com.example.app');
      expect(restored.baseReps, 42);
      expect(restored.minutesGranted, 25);
      expect(restored.isEnabled, isFalse);
    });

    test('uses safe fallbacks for malformed persisted values', () {
      final app = LockedApp.fromJson({
        'packageName': 'com.example.app',
        'baseReps': 'not-a-number',
        'minutesGranted': null,
        'isEnabled': null,
      });

      expect(app.baseReps, 20);
      expect(app.minutesGranted, 15);
      expect(app.isEnabled, isTrue);
    });

    test('defensively clamps persisted numeric values', () {
      final app = LockedApp.fromJson({
        'packageName': 'com.example.app',
        'baseReps': -999,
        'minutesGranted': 9999,
      });

      expect(app.baseReps, 1);
      expect(app.minutesGranted, 180);
    });
  });
}
