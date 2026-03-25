import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/game_state.dart';
import '../models/word_card.dart';

/// Sample word list (in a real app, load from assets or database)
const List<String> sampleWords = [
  'Apple', 'Banana', 'Car', 'Dog', 'Elephant', 'Flower', 'Guitar', 'House', 'Ice', 'Jungle',
  'King', 'Lion', 'Mountain', 'Night', 'Ocean', 'Piano', 'Queen', 'River', 'Sun', 'Tree',
  'Umbrella', 'Violin', 'Water', 'Xylophone', 'Yacht', 'Zebra'
];

/// Notifier for managing game state
class GameNotifier extends StateNotifier<GameState> {
  final Logger _logger = Logger();

  GameNotifier() : super(_generateInitialState());

  /// Generates initial game state with random words and colors
  static GameState _generateInitialState() {
    final random = Random();
    final shuffledWords = sampleWords.toList()..shuffle(random);

    // Color distribution: 9 red, 8 blue, 7 neutral, 1 assassin
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
      currentTurn: Team.red, // Red starts first
    );
  }

  /// Reveals a card at the given index
  void revealCard(int index) {
    if (state.isGameOver) return;

    final card = state.cards[index];
    if (card.isRevealed) return;

    final updatedCards = List<WordCard>.from(state.cards);
    updatedCards[index] = card.copyWith(isRevealed: true);

    Team? winner;
    bool isGameOver = false;

    if (card.color == CardColor.assassin) {
      // TC-03: Assassin revealed, game over
      isGameOver = true;
      winner = state.currentTurn == Team.red ? Team.blue : Team.red;
      _logger.i('Assassin revealed! ${winner.name} wins');
    } else {
      // Check win conditions
      final redCards = updatedCards.where((c) => c.color == CardColor.red && c.isRevealed).length;
      final blueCards = updatedCards.where((c) => c.color == CardColor.blue && c.isRevealed).length;

      if (redCards == 9) {
        isGameOver = true;
        winner = Team.red;
      } else if (blueCards == 8) {
        isGameOver = true;
        winner = Team.blue;
      } else if (card.color != state.currentTurn.cardColor) {
        // Wrong color, switch turn
        state = state.copyWith(currentTurn: state.currentTurn == Team.red ? Team.blue : Team.red);
      }
    }

    state = state.copyWith(
      cards: updatedCards,
      isGameOver: isGameOver,
      winner: winner,
    );

    _logger.i('Card revealed: ${card.word} (${card.color.name}), Turn: ${state.currentTurn.name}');
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