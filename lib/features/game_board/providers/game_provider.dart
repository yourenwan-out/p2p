import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/game_state.dart';
import '../models/word_card.dart';
import '../../core/constants/word_database.dart';

/// Notifier for managing game state
class GameNotifier extends StateNotifier<GameState> {
  final Logger _logger = Logger();

  GameNotifier() : super(_generateInitialState());

  /// Synchronize state from network
  void updateState(GameState newState) {
    state = newState;
  }

  /// Generates initial game state
  static GameState _generateInitialState() {
    final random = Random();
    final shuffledWords = WordDatabase.arabicWords.toList()..shuffle(random);

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
    
    // Number + 1 guesses allowed (if number is not 0 or unlimited. Let's use 99 for unlimited, 0 for 0+1=1)
    int guesses = number == 99 ? 99 : (number + 1);
    
    state = state.copyWith(
      currentClueWord: word,
      currentClueNumber: number,
      remainingGuesses: guesses,
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

    if (card.color == CardColor.assassin) {
      isGameOver = true;
      winner = state.currentTurn == Team.red ? Team.blue : Team.red;
      _logger.i('Assassin revealed! ${winner!.name} wins');
    } else {
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
          state = state.copyWith(remainingGuesses: state.remainingGuesses - 1);
          if (state.remainingGuesses == 0) {
            endTurn = true;
          }
        }
      }
    }

    state = state.copyWith(
      cards: updatedCards,
      isGameOver: isGameOver,
      winner: winner,
    );

    _logger.i('Card revealed: ${card.word} (${card.color.name})');

    if (endTurn && !isGameOver) {
      _switchTurn();
    }
  }

  /// Resets the game
  void resetGame() {
    state = _generateInitialState();
    _logger.i('Game reset');
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