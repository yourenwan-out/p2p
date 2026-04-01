import 'package:freezed_annotation/freezed_annotation.dart';

part 'socket_message.freezed.dart';
part 'socket_message.g.dart'; // هذا السطر ضروري جداً

@freezed
class SocketMessage with _$SocketMessage {
  const factory SocketMessage({
    required String type,
    required Map<String, dynamic> payload,
  }) = _SocketMessage;

  factory SocketMessage.fromJson(Map<String, dynamic> json) =>
      _$SocketMessageFromJson(json);
}