import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/test_result.dart';
import '../../game_board/providers/game_provider.dart';

class EdgeCaseTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testRapidClicking(),
      await _testClickWithoutClue(),
    ];
  }

  static Future<TestResult> _testRapidClicking() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final notifier = container.read(gameProvider.notifier);
      
      // Setup rule: give 99 guesses
      notifier.giveClue('RAPID', 99);
      
      // Simulate 10 rapid clicks on the exact same card
      for (int i = 0; i < 10; i++) {
        notifier.revealCard(10);
      }
      
      final state = container.read(gameProvider);
      // The logic handles "if already revealed return", meaning remainingGuesses only dropped by 1.
      if (!state.cards[10].isRevealed) throw Exception('Card not revealed');
      if (state.remainingGuesses != 99) throw Exception('Remaining guesses decremented multiple times for same card! ${state.remainingGuesses}');

      return TestResult(name: 'Edge Cases: Rapid Clicking', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Edge Cases: Rapid Clicking', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testClickWithoutClue() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final notifier = container.read(gameProvider.notifier);
      
      notifier.resetGame(); // Ensure 0 remaining guesses
      notifier.revealCard(5);
      
      final state = container.read(gameProvider);
      
      // Since no clue given, remainingGuesses is 0, so the card shouldn't flip.
      if (state.cards[5].isRevealed) {
        throw Exception('Card was revealed even though no clue was given (0 remaining guesses)');
      }

      return TestResult(name: 'Edge Cases: Click Without Clue', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Edge Cases: Click Without Clue', status: TestStatus.failed, errorMessage: e.toString());
    }
  }
}
