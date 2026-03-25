import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/test_result.dart';
import '../../game_board/providers/game_provider.dart';
import '../../game_board/models/game_state.dart';
import '../../game_board/models/word_card.dart';

class EngineTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testBoardGeneration(),
      await _testSpymasterClues(),
      await _testOperativeGuessesAndTurnSwitching(),
      await _testNPlusOneRule(),
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

      return TestResult(name: 'Engine: Board Generation', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Engine: Board Generation', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testSpymasterClues() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final notifier = container.read(gameProvider.notifier);
      
      notifier.giveClue('TEST', 2);
      var state = container.read(gameProvider);
      
      if (state.currentClueWord != 'TEST') throw Exception('Clue word did not update');
      if (state.remainingGuesses != 3) throw Exception('Remaining guesses should be N + 1 (2 + 1 = 3)');

      return TestResult(name: 'Engine: Spymaster Clues', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Engine: Spymaster Clues', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testOperativeGuessesAndTurnSwitching() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final notifier = container.read(gameProvider.notifier);
      
      var state = container.read(gameProvider);
      final currentTeam = state.currentTurn;
      final expectedColor = currentTeam == Team.red ? CardColor.red : CardColor.blue;
      
      // 1. Give unlimited guesses to test turn switching by logic, not by guess exhaustion
      notifier.giveClue('UNLIMITED', 99);
      
      // 2. Click correct card (Same Team)
      int sameTeamIdx = state.cards.indexWhere((c) => c.color == expectedColor && !c.isRevealed);
      notifier.revealCard(sameTeamIdx);
      state = container.read(gameProvider);
      
      if (!state.cards[sameTeamIdx].isRevealed) throw Exception('Card was not revealed');
      if (state.currentTurn != currentTeam) throw Exception('Turn switched unexpectedly when picking same-team card');
      if (state.remainingGuesses != 99) throw Exception('Remaining guesses did not decrement'); // 100 -> 99

      // 3. Click neutral card (Should Switch Turn)
      int neutralIdx = state.cards.indexWhere((c) => c.color == CardColor.neutral && !c.isRevealed);
      notifier.revealCard(neutralIdx);
      state = container.read(gameProvider);
      
      if (state.currentTurn == currentTeam) throw Exception('Turn did not switch when picking neutral card');
      if (state.cards[neutralIdx].isRevealed == false) throw Exception('Neutral card not revealed');
      
      // 4. Team switched, so give clue for new team
      final oppositeTeam = state.currentTurn;
      notifier.giveClue('OPPOSITE', 99);
      
      // 5. Click enemy card (Which is the previous team's expectedColor)
      int enemyIdx = state.cards.indexWhere((c) => c.color == expectedColor && !c.isRevealed);
      notifier.revealCard(enemyIdx);
      state = container.read(gameProvider);
      
      if (state.currentTurn == oppositeTeam) throw Exception('Turn did not switch when picking enemy card');

      return TestResult(name: 'Engine: Turn Switching', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Engine: Turn Switching', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testNPlusOneRule() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final notifier = container.read(gameProvider.notifier);
      
      var state = container.read(gameProvider);
      final startTurn = state.currentTurn;
      final startColor = startTurn == Team.red ? CardColor.red : CardColor.blue;
      
      // Give clue with number 2 (So 3 guesses allowed)
      notifier.giveClue('LIMIT', 2);
      
      // Find 3 valid cards
      var validCards = state.cards.where((c) => c.color == startColor && !c.isRevealed).toList();
      
      notifier.revealCard(state.cards.indexWhere((c) => c.id == validCards[0].id)); // Guess 1
      state = container.read(gameProvider);
      if (state.currentTurn != startTurn) throw Exception('Turn ended too early');
      
      notifier.revealCard(state.cards.indexWhere((c) => c.id == validCards[1].id)); // Guess 2
      state = container.read(gameProvider);
      if (state.currentTurn != startTurn) throw Exception('Turn ended too early before N+1');
      
      notifier.revealCard(state.cards.indexWhere((c) => c.id == validCards[2].id)); // Guess 3 (N+1 limit reached)
      state = container.read(gameProvider);
      if (state.currentTurn == startTurn) throw Exception('Turn failed to switch after exhausting N+1 guesses');

      return TestResult(name: 'Engine: N+1 Rule', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Engine: N+1 Rule', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testWinLossConditions() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      
      // Sub-Test 1: Red Wins
      container.read(gameProvider.notifier).resetGame();
      container.read(gameProvider.notifier).giveClue('WIN', 99);
      var state = container.read(gameProvider);
      var redCards = state.cards.where((c) => c.color == CardColor.red).toList();
      for (int i = 0; i < 9; i++) {
        container.read(gameProvider.notifier).revealCard(state.cards.indexWhere((c) => c.id == redCards[i].id));
      }
      state = container.read(gameProvider);
      if (!state.isGameOver || state.winner != Team.red) {
        throw Exception('Red should have won when all 9 cards revealed');
      }

      // Sub-Test 2: Assassin Ends Game
      container.read(gameProvider.notifier).resetGame();
      state = container.read(gameProvider);
      final turnBefore = state.currentTurn;
      container.read(gameProvider.notifier).giveClue('KILL', 99);
      
      int assassinIdx = state.cards.indexWhere((c) => c.color == CardColor.assassin);
      container.read(gameProvider.notifier).revealCard(assassinIdx);
      state = container.read(gameProvider);
      
      if (!state.isGameOver) {
        throw Exception('Assassin did not end the game immediately');
      }
      final expectedWinner = turnBefore == Team.red ? Team.blue : Team.red;
      if (state.winner != expectedWinner) {
        throw Exception('Assassin revealed, but opponent did not win');
      }

      return TestResult(name: 'Engine: Win/Loss Conditions', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Engine: Win/Loss Conditions', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testResetGame() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      
      container.read(gameProvider.notifier).giveClue('TEST', 1);
      container.read(gameProvider.notifier).revealCard(0);
      
      container.read(gameProvider.notifier).resetGame();
      final state = container.read(gameProvider);
      
      if (state.cards.any((c) => c.isRevealed)) throw Exception('Not all cards are hidden after reset');
      if (state.currentClueWord != null) throw Exception('Clue word not reset');
      if (state.isGameOver) throw Exception('Game shouldn\'t be over after reset');

      return TestResult(name: 'Engine: Reset Game', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Engine: Reset Game', status: TestStatus.failed, errorMessage: e.toString());
    }
  }
}
