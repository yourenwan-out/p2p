import 'package:freezed_annotation/freezed_annotation.dart';
import 'game_state.dart'; // For Team enum

part 'player.freezed.dart';
part 'player.g.dart';

/// Role for the player
enum Role {
  spymaster,
  operative,
}

/// Model representing a player in the game
@freezed
class Player with _$Player {
  const factory Player({
    required String id,
    required String name,
    required Team team,
    required Role role,
    @Default(false) bool isHost,
  }) = _Player;

  factory Player.fromJson(Map<String, dynamic> json) => _$PlayerFromJson(json);
}
