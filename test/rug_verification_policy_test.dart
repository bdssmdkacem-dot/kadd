import 'package:flutter_test/flutter_test.dart';
import 'package:kadd/services/rug_verification_policy.dart';

void main() {
  final base = DateTime(2026, 9, 10, 10, 0, 0);

  List<DateTime> captures({
    Duration second = const Duration(seconds: 1),
    Duration third = const Duration(seconds: 2),
  }) => [base, base.add(second), base.add(third)];

  test('accepts three strong and consistently timed captures', () {
    expect(
      RugVerificationPolicy.passes(
        [0.90, 0.87, 0.88],
        captureTimes: captures(),
      ),
      isTrue,
    );
  });

  test('rejects when one capture is weak', () {
    expect(
      RugVerificationPolicy.passes(
        [0.95, 0.90, 0.69],
        captureTimes: captures(),
      ),
      isFalse,
    );
  });

  test('rejects inconsistent confidence even when average is high', () {
    expect(
      RugVerificationPolicy.passes(
        [0.99, 0.86, 0.70],
        captureTimes: captures(),
      ),
      isFalse,
    );
  });

  test('rejects an incomplete verification session', () {
    expect(
      RugVerificationPolicy.passes(
        [0.95, 0.92],
        captureTimes: captures(),
      ),
      isFalse,
    );
  });

  test('rejects captures that are too close together', () {
    expect(
      RugVerificationPolicy.passes(
        [0.95, 0.92, 0.91],
        captureTimes: captures(
          second: const Duration(milliseconds: 799),
          third: const Duration(seconds: 2),
        ),
      ),
      isFalse,
    );
  });

  test('rejects a session that takes too long', () {
    expect(
      RugVerificationPolicy.passes(
        [0.95, 0.92, 0.91],
        captureTimes: captures(third: const Duration(seconds: 21)),
      ),
      isFalse,
    );
  });

  test('rejects missing capture timestamps', () {
    expect(RugVerificationPolicy.passes([0.90, 0.87, 0.88]), isFalse);
  });

  test('rejects invalid confidence values', () {
    expect(
      RugVerificationPolicy.passes(
        [0.90, 1.01, 0.88],
        captureTimes: captures(),
      ),
      isFalse,
    );
  });

  test('calculates average confidence', () {
    expect(RugVerificationPolicy.average([0.80, 0.90, 1.00]), closeTo(0.90, 0.0001));
    expect(RugVerificationPolicy.average(const []), 0.0);
  });
}
