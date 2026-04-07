import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/appwrite/appwrite_providers.dart';
import '../models/test_result.dart';

class StartupTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testHiveInit(),
      await _testNetworkIPFetch(),
      await _testAppwriteSession(),
    ];
  }

  static Future<TestResult> _testHiveInit() async {
    final startTime = DateTime.now();
    try {
      await Future.microtask(() async {
        if (!Hive.isBoxOpen('settingsBox')) {
          await Hive.openBox('settingsBox');
        }
      }).timeout(const Duration(seconds: 4));
      return TestResult(
        name: 'Startup: Hive initialization',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(
        name: 'Startup: Hive initialization',
        status: TestStatus.failed,
        errorMessage: 'Timeout/Error: $e',
      );
    }
  }

  static Future<TestResult> _testNetworkIPFetch() async {
    final startTime = DateTime.now();
    try {
      await NetworkInterface.list().timeout(const Duration(seconds: 3));
      return TestResult(
        name: 'Startup: Network IP fetching',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(
        name: 'Startup: Network IP fetching',
        status: TestStatus.failed,
        errorMessage: 'Timeout/Error: $e',
      );
    }
  }

  static Future<TestResult> _testAppwriteSession() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      await container.read(authServiceProvider)
          .ensureAnonymousSession()
          .timeout(const Duration(seconds: 8));
      return TestResult(
        name: 'Startup: Appwrite Anonymous Session',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(
        name: 'Startup: Appwrite Anonymous Session',
        status: TestStatus.failed,
        errorMessage: 'Timeout/Error: $e',
      );
    }
  }
}
