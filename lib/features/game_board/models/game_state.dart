import 'package:freezed_annotation/freezed_annotation.dart';
import 'word_card.dart';

import 'player.dart';

part 'game_state.freezed.dart';
part 'game_state.g.dart';

/// Enum for teams
enum Team {
  red,
  blue,
}

/// Model for the overall game state
@freezed
class GameState with _$GameState {
  const factory GameState({
    @Default([]) List<Player> players,
    required List<WordCard> cards,
    required Team currentTurn,
    String? currentClueWord,
    int? currentClueNumber,
    @Default(0) int remainingGuesses,
    @Default(false) bool isGameOver,
    Team? winner,
    @Default(0) int redScore,
    @Default(0) int blueScore,
    // Last card reveal result for UI feedback
    CardColor? lastRevealedColor,
  }) = _GameState;

  factory GameState.fromJson(Map<String, dynamic> json) =>
      _$GameStateFromJson(json);
}