import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_codenames/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('validateIPAddress returns null for valid IP', () {
      expect(Validators.validateIPAddress('192.168.1.1'), isNull);
      expect(Validators.validateIPAddress('10.0.0.1'), isNull);
    });

    test('validateIPAddress returns error for invalid IP', () {
      expect(Validators.validateIPAddress('256.1.1.1'), isNotNull);
      expect(Validators.validateIPAddress('192.168.1'), isNotNull);
      expect(Validators.validateIPAddress('abc.def.ghi.jkl'), isNotNull);
      expect(Validators.validateIPAddress(''), isNotNull);
      expect(Validators.validateIPAddress(null), isNotNull);
    });
  });
}