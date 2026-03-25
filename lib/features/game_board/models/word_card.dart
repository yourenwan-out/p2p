import 'package:freezed_annotation/freezed_annotation.dart';

part 'word_card.freezed.dart';
part 'word_card.g.dart';

/// Enum for card colors
enum CardColor {
  red,
  blue,
  neutral,
  assassin,
}

/// Model for a word card in the game
@freezed
class WordCard with _$WordCard {
  const factory WordCard({
    required int id,
    required String word,
    required CardColor color,
    @Default(false) bool isRevealed,
  }) = _WordCard;

  factory WordCard.fromJson(Map<String, dynamic> json) =>
      _$WordCardFromJson(json);
}