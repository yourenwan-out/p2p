import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/test_result.dart';
import '../../../../core/appwrite/appwrite_providers.dart';

class AppwriteTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testAppwriteInit(),
      await _testRoomServiceInjection(),
    ];
  }

  static Future<TestResult> _testAppwriteInit() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final client = container.read(appwriteClientProvider);
      if (client.endPoint.isEmpty) throw Exception('Endpoint is empty');
      // The getter is actually project in the dart sdk? Or maybe we just check client is not null
      if (client == null) throw Exception('Client is null');

      return TestResult(
        name: 'Appwrite: Client Initialization',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Appwrite: Client Initialization', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testRoomServiceInjection() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final service = container.read(appwriteRoomServiceProvider);
      if (service == null) throw Exception('Room Service is null');
      
      return TestResult(
        name: 'Appwrite: Room Service Injection',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Appwrite: Room Service Injection', status: TestStatus.failed, errorMessage: e.toString());
    }
  }
}
