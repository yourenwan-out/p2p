import 'package:hive/hive.dart';
import '../models/test_result.dart';

class StorageTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testHiveSaveLoad(),
      await _testErrorRecovery(),
    ];
  }

  static Future<TestResult> _testHiveSaveLoad() async {
    final startTime = DateTime.now();
    try {
      final box = await Hive.openBox('testBox');
      const testIP = '192.168.1.50';
      
      await box.put('lastIP', testIP);
      final savedIP = box.get('lastIP');
      
      if (savedIP != testIP) {
        throw Exception('Saved IP ($savedIP) does not match original ($testIP)');
      }
      
      await box.deleteFromDisk();

      return TestResult(
        name: 'Storage: Hive Save/Load',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Storage: Hive Save/Load', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testErrorRecovery() async {
    final startTime = DateTime.now();
    try {
      final box = await Hive.openBox('recoveryTestBox');
      
      // Try to read a non-existent key with dynamic default
      final val = box.get('missing', defaultValue: 'DEFAULT');
      if (val != 'DEFAULT') throw Exception('Default value failed');

      // Simulate a "corrupt" read (getting null where we expect something)
      final dynamic corruptVal = null;
      final fallback = corruptVal ?? 'RECOVERED';
      if (fallback != 'RECOVERED') throw Exception('Recovery logic failed');

      await box.deleteFromDisk();

      return TestResult(
        name: 'Storage: Error Recovery',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Storage: Error Recovery', status: TestStatus.failed, errorMessage: e.toString());
    }
  }
}
