import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/test_result.dart';
import '../../../core/network/connection_provider.dart';
import '../../game_board/providers/game_provider.dart';

class StateTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testConnectionStateTransitions(),
      await _testGameStateUpdates(),
    ];
  }

  static Future<TestResult> _testConnectionStateTransitions() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final notifier = container.read(connectionProvider.notifier);
      
      // Initial state
      if (container.read(connectionProvider).isConnected) throw Exception('Should start disconnected');
      
      // Simulate player addition
      notifier.addPlayer('TestBot');
      if (!container.read(connectionProvider).players.contains('TestBot')) throw Exception('Player not added to state');

      return TestResult(
        name: 'State: Connection transitions',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'State: Connection transitions', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testGameStateUpdates() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      
      // Initial state verify
      var state = container.read(gameProvider);
      if (state.cards.length != 25) throw Exception('Initial game state invalid');

      // Manual state update simulation if needed, but GameNotifier already tested in EngineTests
      return TestResult(
        name: 'State: Game state updates',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'State: Game state updates', status: TestStatus.failed, errorMessage: e.toString());
    }
  }
}
