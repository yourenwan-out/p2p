import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'models/socket_message.dart';

/// Socket client for connecting to the host
class SocketClient {
  Socket? _socket;
  final Logger _logger = Logger();
  final Function(SocketMessage) onMessageReceived;
  final String localPlayerId;

  SocketClient({required this.onMessageReceived, required this.localPlayerId});

  /// Connects to the host at the given IP
  Future<void> connect(String ip, String playerName) async {
    try {
      _socket = await Socket.connect(ip, 4567, timeout: const Duration(seconds: 5));
      _logger.i('Connected to host: $ip');

      // Send join request
      final message = SocketMessage(
        type: 'REQ_JOIN',
        payload: {
          'id': localPlayerId,
          'name': playerName,
          'team': 'red',
          'role': 'operative',
        },
      );
      _sendMessage(message);

      _listenForMessages();
    } on SocketException catch (e) {
      _logger.e('Connection failed: ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Unexpected error: $e');
      rethrow;
    }
  }

  /// Sends a message to the host
  void _sendMessage(SocketMessage message) {
    if (_socket != null) {
      final json = jsonEncode(message.toJson());
      _socket!.write('$json\n');
      _logger.i('Sent message: ${message.type}');
    }
  }

  /// Listens for incoming messages from the host
  void _listenForMessages() {
    _socket?.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      (message) {
        try {
          if (message.isEmpty) return;
          final json = jsonDecode(message) as Map<String, dynamic>;
          final socketMessage = SocketMessage.fromJson(json);
          _logger.i('Received message: ${socketMessage.type}');

          onMessageReceived(socketMessage);
        } catch (e) {
          _logger.e('Error parsing message: $e');
        }
      },
      onDone: () {
        _logger.i('Disconnected from host');
      },
      onError: (error) {
        _logger.e('Connection error: $error');
      },
    );
  }

  /// Sends a message (public)
  void sendMessage(SocketMessage message) {
    _sendMessage(message);
  }

  /// Disconnects from the host
  void disconnect() {
    _socket?.close();
    _socket = null;
    _logger.i('Disconnected');
  }
}