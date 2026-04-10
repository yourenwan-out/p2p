import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/game_state.dart';
import '../models/word_card.dart';
import '../../../core/constants/word_database.dart';

/// Notifier for managing game state
class GameNotifier extends StateNotifier<GameState> {
  final Logger _logger = Logger();

  GameNotifier() : super(_generateInitialState());

  /// Synchronize state from network
  void updateState(GameState newState) {
    state = newState;
  }

  /// Generates initial game state
  static GameState _generateInitialState({List<String>? customWords}) {
    final random = Random();
    List<String> shuffledWords;
    
    if (customWords != null && customWords.isNotEmpty) {
      if (customWords.length < 25) {
        final defaultWords = WordDatabase.arabicWords.toList()..shuffle(random);
        // Exclude already provided words
        final needed = 25 - customWords.length;
        final remainingDefaults = defaultWords.where((w) => !customWords.contains(w)).take(needed).toList();
        final mixedWords = [...customWords, ...remainingDefaults];
        shuffledWords = mixedWords.toList()..shuffle(random);
      } else {
        shuffledWords = customWords.toList()..shuffle(random);
      }
    } else {
      shuffledWords = WordDatabase.arabicWords.toList()..shuffle(random);
    }

    final colors = <CardColor>[];
    colors.addAll(List.filled(9, CardColor.red));
    colors.addAll(List.filled(8, CardColor.blue));
    colors.addAll(List.filled(7, CardColor.neutral));
    colors.add(CardColor.assassin);
    colors.shuffle(random);

    final cards = List.generate(25, (index) => WordCard(
      id: index,
      word: shuffledWords[index],
      color: colors[index],
    ));

    return GameState(
      cards: cards,
      currentTurn: Team.red,
    );
  }

  /// Spymaster gives a clue
  void giveClue(String word, int number) {
    if (state.isGameOver) return;
    
    // Official Rules: Number 0 and Infinity (99) both allow unlimited guesses.
    // Otherwise, guesses = number + 1
    int guesses = (number == 99 || number == 0) ? 99 : (number + 1);
    
    state = state.copyWith(
      currentClueWord: word,
      currentClueNumber: number,
      remainingGuesses: guesses,
      lastRevealedColor: null, // clear last result when new clue is given
    );
    _logger.i('Clue given: $word : $number. Guesses allowed: $guesses');
  }

  /// Operative voluntarily passes the turn
  void passTurn() {
    if (state.isGameOver) return;
    _switchTurn();
  }

  void _switchTurn() {
    state = state.copyWith(
      currentTurn: state.currentTurn == Team.red ? Team.blue : Team.red,
      currentClueWord: null,
      currentClueNumber: null,
      remainingGuesses: 0,
    );
    _logger.i('Turn switched to: ${state.currentTurn.name}');
  }

  /// Reveals a card at the given index
  void revealCard(int index) {
    if (index < 0) throw Exception('Should throw error on negative index');
    if (index > 24) throw Exception('Should throw error on index > 24');
    if (state.isGameOver) return;
    
    // Check if they are allowed to guess
    if (state.remainingGuesses <= 0) {
      _logger.w('Cannot reveal card: No guesses remaining or no clue given yet.');
      return; 
    }

    final card = state.cards[index];
    if (card.isRevealed) return;

    final updatedCards = List<WordCard>.from(state.cards);
    updatedCards[index] = card.copyWith(isRevealed: true);

    Team? winner;
    bool isGameOver = false;
    bool endTurn = false;
    int newRedScore = state.redScore;
    int newBlueScore = state.blueScore;

    if (card.color == CardColor.assassin) {
      isGameOver = true;
      winner = state.currentTurn == Team.red ? Team.blue : Team.red;
      _logger.i('Assassin revealed! ${winner.name} wins');
    } else {
      // Update scores: only count cards belonging to each team
      if (card.color == CardColor.red) newRedScore++;
      if (card.color == CardColor.blue) newBlueScore++;

      final redCards = updatedCards.where((c) => c.color == CardColor.red && c.isRevealed).length;
      final blueCards = updatedCards.where((c) => c.color == CardColor.blue && c.isRevealed).length;

      if (redCards == 9) {
        isGameOver = true;
        winner = Team.red;
      } else if (blueCards == 8) {
        isGameOver = true;
        winner = Team.blue;
      } else if (card.color != state.currentTurn.cardColor) {
        // Wrong color (neutral or enemy), end turn immediately
        endTurn = true;
      } else {
        // Correct color! Decrement guesses
        if (state.remainingGuesses != 99) { // 99 means unlimited
          state = state.copyWith(
            remainingGuesses: state.remainingGuesses - 1,
            redScore: newRedScore,
            blueScore: newBlueScore,
            lastRevealedColor: card.color,
          );
          if (state.remainingGuesses == 0) {
            endTurn = true;
          }
          _logger.i('Card revealed: ${card.word} (${card.color.name})');
          if (endTurn && !isGameOver) _switchTurn();
          return;
        }
      }
    }

    state = state.copyWith(
      cards: updatedCards,
      isGameOver: isGameOver,
      winner: winner,
      redScore: newRedScore,
      blueScore: newBlueScore,
      lastRevealedColor: card.color,
    );

    _logger.i('Card revealed: ${card.word} (${card.color.name})');

    if (endTurn && !isGameOver) {
      _switchTurn();
    }
  }

  /// Resets the game with fresh state (new words, new layout)
  void resetGame({List<String>? customWords}) {
    state = _generateInitialState(customWords: customWords);
    _logger.i('Game reset - new board generated');
  }
}

/// Extension for Team to get card color
extension TeamExtension on Team {
  CardColor get cardColor {
    switch (this) {
      case Team.red:
        return CardColor.red;
      case Team.blue:
        return CardColor.blue;
    }
  }
}

/// Provider for game state
final gameProvider = StateNotifierProvider<GameNotifier, GameState>(
  (ref) => GameNotifier(),
);