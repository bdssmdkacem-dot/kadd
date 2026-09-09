import 'package:flutter_test/flutter_test.dart';
import 'package:kadd/services/rug_verification_policy.dart';

void main() {
  test('accepts three strong and consistent captures', () {
    expect(RugVerificationPolicy.passes([0.90, 0.87, 0.88]), isTrue);
  });

  test('rejects when one capture is weak', () {
    expect(RugVerificationPolicy.passes([0.95, 0.90, 0.69]), isFalse);
  });

  test('rejects inconsistent confidence even when average is high', () {
    expect(RugVerificationPolicy.passes([0.99, 0.86, 0.70]), isFalse);
  });

  test('rejects an incomplete verification session', () {
    expect(RugVerificationPolicy.passes([0.95, 0.92]), isFalse);
  });

  test('calculates average confidence', () {
    expect(RugVerificationPolicy.average([0.80, 0.90, 1.00]), closeTo(0.90, 0.0001));
    expect(RugVerificationPolicy.average(const []), 0.0);
  });
}
