import 'package:freezed_annotation/freezed_annotation.dart';
import 'word_card.dart';

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
    required List<WordCard> cards,
    required Team currentTurn,
    @Default(false) bool isGameOver,
    Team? winner,
  }) = _GameState;

  factory GameState.fromJson(Map<String, dynamic> json) =>
      _$GameStateFromJson(json);
}