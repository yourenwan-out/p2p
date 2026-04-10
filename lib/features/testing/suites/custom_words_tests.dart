import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/test_result.dart';
import '../../game_board/providers/game_provider.dart';
import '../../../core/constants/word_database.dart';

class CustomWordsTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testExact25Words(),
      await _testTooFewWords(),
      await _testTooManyWords(),
    ];
  }

  static Future<TestResult> _testExact25Words() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final customList = List.generate(25, (index) => 'كلمة_مخصصة_$index');
      
      container.read(gameProvider.notifier).resetGame(customWords: customList);
      final state = container.read(gameProvider);

      if (state.cards.length != 25) throw Exception('Board does not have exactly 25 cards');
      
      for (var card in state.cards) {
        if (!customList.contains(card.word)) {
          throw Exception('Board contains a word not in the custom list: ${card.word}');
        }
      }

      return TestResult(name: 'Custom Words: Exact 25 Words', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Custom Words: Exact 25 Words', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testTooFewWords() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final customList = ['كلمة_مخصصة_1', 'كلمة_مخصصة_2']; // Only 2 words
      
      container.read(gameProvider.notifier).resetGame(customWords: customList);
      final state = container.read(gameProvider);

      if (state.cards.length != 25) throw Exception('Board does not have exactly 25 cards');
      
      int customFound = 0;
      for (var card in state.cards) {
        if (customList.contains(card.word)) customFound++;
      }

      if (customFound != 2) throw Exception('Board did not include all 2 custom words');
      
      // The rest should be from default word list
      int defaultFound = 0;
      for (var card in state.cards) {
        if (WordDatabase.arabicWords.contains(card.word)) defaultFound++;
      }
      
      if (defaultFound != 23) throw Exception('Board did not include exactly 23 default words');

      return TestResult(name: 'Custom Words: Too Few Words (Padding)', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Custom Words: Too Few Words (Padding)', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testTooManyWords() async {
    final startTime = DateTime.now();
    try {
      final container = ProviderContainer();
      final customList = List.generate(50, (index) => 'كلمة_كثيرة_$index');
      
      container.read(gameProvider.notifier).resetGame(customWords: customList);
      final state = container.read(gameProvider);

      if (state.cards.length != 25) throw Exception('Board does not have exactly 25 cards');
      
      for (var card in state.cards) {
        if (!customList.contains(card.word)) {
          throw Exception('Board contains a word not in the custom list');
        }
      }

      return TestResult(name: 'Custom Words: Too Many Words (Trimming)', status: TestStatus.passed, duration: DateTime.now().difference(startTime));
    } catch (e) {
      return TestResult(name: 'Custom Words: Too Many Words (Trimming)', status: TestStatus.failed, errorMessage: e.toString());
    }
  }
}
