import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/test_result.dart';
import '../../game_board/providers/game_provider.dart';
import '../../game_board/models/game_state.dart';
import '../../game_board/models/word_card.dart';

class EngineTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testBoardGeneration(),
      await _testCardRevealing(),
      await _testTurnSwitching(),
      await _testWinLossConditions(),
      await _testResetGame(),
    ];
  }

  static Future<TestResult> _testBoardGeneration() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final state = container.read(gameProvider);

      if (state.cards.length != 25) throw Exception('Board does not have exactly 25 cards');
      
      int redCount = state.cards.where((c) => c.color == CardColor.red).length;
      int blueCount = state.cards.where((c) => c.color == CardColor.blue).length;
      int neutralCount = state.cards.where((c) => c.color == CardColor.neutral).length;
      int assassinCount = state.cards.where((c) => c.color == CardColor.assassin).length;

      if (redCount != 9) throw Exception('Expected 9 red cards, got $redCount');
      if (blueCount != 8) throw Exception('Expected 8 blue cards, got $blueCount');
      if (neutralCount != 7) throw Exception('Expected 7 neutral cards, got $neutralCount');
      if (assassinCount != 1) throw Exception('Expected 1 assassin card, got $assassinCount');

      // Verify unique IDs
      final ids = state.cards.map((c) => c.id).toSet();
      if (ids.length != 25) throw Exception('Card IDs are not unique');

      return TestResult(
        name: 'Engine: Board Generation',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Engine: Board Generation', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testCardRevealing() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      var state = container.read(gameProvider);
      
      int testIndex = 0;
      // Change status to revealed
      container.read(gameProvider.notifier).revealCard(testIndex);
      state = container.read(gameProvider);
      
      if (!state.cards[testIndex].isRevealed) {
        throw Exception('Card was not revealed');
      }

      // Ignore if already revealed (should not throw)
      container.read(gameProvider.notifier).revealCard(testIndex);
      
      // Out of bounds error checking
      bool threwNegative = false;
      try {
        container.read(gameProvider.notifier).revealCard(-1);
      } catch (e) {
        if (e.toString().contains('Should throw error on negative index')) {
          threwNegative = true;
        }
      }
      if (!threwNegative) throw Exception('Should throw error on negative index');
      
      bool threwOutOfBounds = false;
      try {
        container.read(gameProvider.notifier).revealCard(25);
      } catch (e) {
        if (e.toString().contains('Should throw error on index > 24')) {
          threwOutOfBounds = true;
        }
      }
      if (!threwOutOfBounds) throw Exception('Should throw error on index > 24');

      return TestResult(
        name: 'Engine: Card Revealing',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Engine: Card Revealing', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testTurnSwitching() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      
      // We need to force a specific board to test reliably, but we can't easily because GameNotifier generates random board.
      // So we will find cards on the generated board.
      var state = container.read(gameProvider);
      final currentTeam = state.currentTurn;
      final expectedColor = currentTeam == Team.red ? CardColor.red : CardColor.blue;
      
      // Find a card of the current team color
      int sameTeamIdx = state.cards.indexWhere((c) => c.color == expectedColor && !c.isRevealed);
      container.read(gameProvider.notifier).revealCard(sameTeamIdx);
      state = container.read(gameProvider);
      if (state.currentTurn != currentTeam) {
        throw Exception('Turn switched unexpectedly when picking same-team card');
      }

      // Find a neutral card
      int neutralIdx = state.cards.indexWhere((c) => c.color == CardColor.neutral && !c.isRevealed);
      container.read(gameProvider.notifier).revealCard(neutralIdx);
      state = container.read(gameProvider);
      if (state.currentTurn == currentTeam) {
        throw Exception('Turn did not switch when picking neutral card');
      }
      
      final oppositeTeam = state.currentTurn;
      
      // Find enemy card
      int enemyIdx = state.cards.indexWhere((c) => c.color == expectedColor && !c.isRevealed); // Now enemy color
      container.read(gameProvider.notifier).revealCard(enemyIdx);
      state = container.read(gameProvider);
      if (state.currentTurn == oppositeTeam) {
        throw Exception('Turn did not switch when picking enemy card');
      }

      return TestResult(
        name: 'Engine: Turn Switching',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Engine: Turn Switching', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testWinLossConditions() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      
      // Sub-Test 1: Red Wins
      container.read(gameProvider.notifier).resetGame();
      var state = container.read(gameProvider);
      var redCards = state.cards.where((c) => c.color == CardColor.red).toList();
      for (int i = 0; i < 9; i++) {
        container.read(gameProvider.notifier).revealCard(redCards[i].id);
      }
      state = container.read(gameProvider);
      if (!state.isGameOver || state.winner != Team.red) {
        throw Exception('Red should have won');
      }

      // Sub-Test 2: Blue Wins
      container.read(gameProvider.notifier).resetGame();
      state = container.read(gameProvider);
      var blueCards = state.cards.where((c) => c.color == CardColor.blue).toList();
      for (int i = 0; i < 8; i++) {
        container.read(gameProvider.notifier).revealCard(blueCards[i].id);
      }
      state = container.read(gameProvider);
      if (!state.isGameOver || state.winner != Team.blue) {
        throw Exception('Blue should have won');
      }

      // Sub-Test 3: Assassin Ends Game
      container.read(gameProvider.notifier).resetGame();
      state = container.read(gameProvider);
      int assassinIdx = state.cards.indexWhere((c) => c.color == CardColor.assassin);
      final currentTurnBeforeAssassin = state.currentTurn;
      container.read(gameProvider.notifier).revealCard(assassinIdx);
      state = container.read(gameProvider);
      
      if (!state.isGameOver) {
        throw Exception('Assassin did not end the game immediately');
      }
      
      final expectedWinner = currentTurnBeforeAssassin == Team.red ? Team.blue : Team.red;
      if (state.winner != expectedWinner) {
        throw Exception('Assassin revealed, but opponent did not win');
      }

      return TestResult(
        name: 'Engine: Win/Loss Conditions',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Engine: Win/Loss Conditions', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testResetGame() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      
      // Make some changes
      container.read(gameProvider.notifier).revealCard(0);
      container.read(gameProvider.notifier).revealCard(1);
      
      final firstBoardIds = container.read(gameProvider).cards.map((e) => e.word).join(',');

      // Reset
      container.read(gameProvider.notifier).resetGame();
      final state = container.read(gameProvider);
      
      if (state.cards.any((c) => c.isRevealed)) {
        throw Exception('Not all cards are hidden after reset');
      }
      
      if (state.isGameOver) {
        throw Exception('Game shouldn\'t be over after reset');
      }
      
      final secondBoardIds = state.cards.map((e) => e.word).join(',');
      if (firstBoardIds == secondBoardIds) {
        // Technically this could happen by an extreme 1-in-a-million chance, but effectively impossible
        throw Exception('Board words didn\'t shuffle');
      }

      return TestResult(
        name: 'Engine: Reset Game',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Engine: Reset Game', status: TestStatus.failed, errorMessage: e.toString());
    }
  }
}
