import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/test_result.dart';
import '../suites/engine_tests.dart';
import '../suites/network_tests.dart';
import '../suites/validator_tests.dart';
import '../suites/storage_tests.dart';
import '../suites/edge_case_tests.dart';
import '../suites/state_tests.dart';

class TestRunnerScreen extends ConsumerStatefulWidget {
  const TestRunnerScreen({super.key});

  @override
  ConsumerState<TestRunnerScreen> createState() => _TestRunnerScreenState();
}

class _TestRunnerScreenState extends ConsumerState<TestRunnerScreen> {
  bool _isRunning = false;
  List<TestResult> _results = [];

  @override
  void initState() {
    super.initState();
    _initializeTests();
  }

  void _initializeTests() {
    setState(() {
      _results = [
        TestResult(name: 'Engine: Board Generation'),
        TestResult(name: 'Engine: Card Revealing'),
        TestResult(name: 'Engine: Turn Switching'),
        TestResult(name: 'Engine: Win/Loss Conditions'),
        TestResult(name: 'Engine: Reset Game'),
        TestResult(name: 'Network: Host Lifecycle'),
        TestResult(name: 'Network: Client Lifecycle'),
        TestResult(name: 'Network: Serialization'),
        TestResult(name: 'Validators: IP Validator'),
        TestResult(name: 'Validators: Name Validator'),
        TestResult(name: 'Storage: Hive Save/Load'),
        TestResult(name: 'Storage: Error Recovery'),
        TestResult(name: 'State: Connection transitions'),
        TestResult(name: 'State: Game state updates'),
        TestResult(name: 'Edge Cases: Rapid Clicking'),
        TestResult(name: 'Edge Cases: Rogue Client'),
      ];
    });
  }

  Future<void> _updateResult(String name, TestStatus status, {String? error, Duration? duration}) async {
    setState(() {
      final index = _results.indexWhere((r) => r.name == name);
      if (index != -1) {
        _results[index] = _results[index].copyWith(
          status: status,
          errorMessage: error,
          duration: duration,
        );
      }
    });
  }

  Future<void> _runAllTests() async {
    if (_isRunning) return;
    
    setState(() {
      _isRunning = true;
      _initializeTests();
    });

    final suites = [
      () => EngineTests.run(),
      () => NetworkTests.run(),
      () => ValidatorTests.run(),
      () => StorageTests.run(),
      () => StateTests.run(),
      () => EdgeCaseTests.run(),
    ];

    for (var suiteFn in suites) {
      try {
        final results = await suiteFn();
        for (var res in results) {
          await _updateResult(res.name, res.status, error: res.errorMessage, duration: res.duration);
        }
      } catch (e) {
        debugPrint('Suite failed: $e');
      }
    }
    
    setState(() {
      _isRunning = false;
    });
  }

  Widget _buildStatusIcon(TestStatus status) {
    switch (status) {
      case TestStatus.pending:
        return Icon(Icons.schedule, color: Colors.grey, size: 24.w);
      case TestStatus.running:
        return SizedBox(
          width: 20.w,
          height: 20.w,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      case TestStatus.passed:
        return Icon(Icons.check_circle, color: Colors.green, size: 24.w);
      case TestStatus.failed:
        return Icon(Icons.cancel, color: Colors.red, size: 24.w);
    }
  }

  @override
  Widget build(BuildContext context) {
    int passed = _results.where((r) => r.status == TestStatus.passed).length;
    int failed = _results.where((r) => r.status == TestStatus.failed).length;
    int total = _results.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Self-Test Diagnostics 🧪'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _initializeTests,
            tooltip: 'Reset Tests',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Total', style: TextStyle(fontSize: 14.sp)),
                    Text('$total', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    Text('Passed', style: TextStyle(fontSize: 14.sp, color: Colors.green)),
                    Text('$passed', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                Column(
                  children: [
                    Text('Failed', style: TextStyle(fontSize: 14.sp, color: Colors.red)),
                    Text('$failed', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: ExpansionTile(
                    title: Text(result.name, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    trailing: _buildStatusIcon(result.status),
                    children: [
                      if (result.errorMessage != null)
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Text(
                            result.errorMessage!,
                            style: TextStyle(color: Colors.red, fontSize: 13.sp),
                          ),
                        )
                      else if (result.status == TestStatus.passed)
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Text(
                            'Tested successfully in ${result.duration?.inMilliseconds ?? 0}ms.',
                            style: TextStyle(color: Colors.green, fontSize: 13.sp),
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Text(
                            'Test not executed yet.',
                            style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _runAllTests,
              icon: _isRunning 
                  ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Running Tests...' : 'Run All Tests'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50.h),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
