import 'package:flutter/material.dart';

enum TestStatus { pending, running, passed, failed }

class TestResult {
  final String name;
  final TestStatus status;
  final String? errorMessage;
  final Duration? duration;

  TestResult({
    required this.name,
    this.status = TestStatus.pending,
    this.errorMessage,
    this.duration,
  });

  TestResult copyWith({
    String? name,
    TestStatus? status,
    String? errorMessage,
    Duration? duration,
  }) {
    return TestResult(
      name: name ?? this.name,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      duration: duration ?? this.duration,
    );
  }
}
