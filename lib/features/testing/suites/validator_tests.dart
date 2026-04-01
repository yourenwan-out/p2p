import '../models/test_result.dart';
import '../../../core/utils/validators.dart';

class ValidatorTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testIPValidator(),
      await _testPlayerNameValidator(),
    ];
  }

  static Future<TestResult> _testIPValidator() async {
    final startTime = DateTime.now();
    try {
      // Valid IPs
      if (Validators.validateIPAddress('192.168.1.1') != null) throw Exception('Failed to validate 192.168.1.1');
      if (Validators.validateIPAddress('127.0.0.1') != null) throw Exception('Failed to validate 127.0.0.1');
      if (Validators.validateIPAddress('10.0.0.1') != null) throw Exception('Failed to validate 10.0.0.1');

      // Invalid IPs
      if (Validators.validateIPAddress('256.0.0.1') == null) throw Exception('Accepted 256.0.0.1');
      if (Validators.validateIPAddress('1.2.3') == null) throw Exception('Accepted 1.2.3');
      if (Validators.validateIPAddress('a.b.c.d') == null) throw Exception('Accepted a.b.c.d');
      if (Validators.validateIPAddress('') == null) throw Exception('Accepted empty IP');
      if (Validators.validateIPAddress(' -1.2.3.4') == null) throw Exception('Accepted negative octet');

      return TestResult(
        name: 'Validators: IP Validator',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Validators: IP Validator', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testPlayerNameValidator() async {
    final startTime = DateTime.now();
    try {
      // Assuming a simple rule: non-empty and < 20 chars
      String? validate(String name) {
        if (name.isEmpty) return 'Name cannot be empty';
        if (name.length > 20) return 'Name too long';
        return null;
      }

      if (validate('ValidName') != null) throw Exception('Failed valid name');
      if (validate('') == null) throw Exception('Accepted empty name');
      if (validate('A very long name that exceeds twenty characters') == null) throw Exception('Accepted long name');

      return TestResult(
        name: 'Validators: Name Validator',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Validators: Name Validator', status: TestStatus.failed, errorMessage: e.toString());
    }
  }
}
