import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:logger/logger.dart';
import 'models/socket_message.dart';

/// Sample word list (should be moved to a shared location)
const List<String> sampleWords = [
  'Apple', 'Banana', 'Car', 'Dog', 'Elephant', 'Flower', 'Guitar', 'House', 'Ice', 'Jungle',
  'King', 'Lion', 'Mountain', 'Night', 'Ocean', 'Piano', 'Queen', 'River', 'Sun', 'Tree',
  'Umbrella', 'Violin', 'Water', 'Xylophone', 'Yacht', 'Zebra'
];

/// Socket host for managing server-side connections
class SocketHost {
  static const int port = 4567;
  ServerSocket? _serverSocket;
  final List<Socket> _clients = [];
  final Logger _logger = Logger();
  List<Map<String, dynamic>>? _gameCards; // Store game state

  /// Starts the server and listens for connections
  Future<void> startServer() async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _logger.i('Server started on port $port');

      // Generate game state
      _generateGameState();

      _serverSocket!.listen((Socket client) {
        _logger.i('Client connected: ${client.remoteAddress.address}');
        _clients.add(client);
        _handleClient(client);
      });
    } catch (e) {
      _logger.e('Failed to start server: $e');
      rethrow;
    }
  }

  /// Generates random game state
  void _generateGameState() {
    final random = Random();
    final shuffledWords = sampleWords.toList()..shuffle(random);

    final colors = <String>[];
    colors.addAll(List.filled(9, 'red'));
    colors.addAll(List.filled(8, 'blue'));
    colors.addAll(List.filled(7, 'neutral'));
    colors.add('assassin');
    colors.shuffle(random);

    _gameCards = List.generate(25, (index) => {
      'id': index,
      'word': shuffledWords[index],
      'color': colors[index],
      'isRevealed': false,
    });

    _logger.i('Game state generated');
  }

  /// Handles incoming data from a client
  void _handleClient(Socket client) {
    client.listen(
      (data) {
        try {
          final message = utf8.decode(data);
          final json = jsonDecode(message) as Map<String, dynamic>;
          final socketMessage = SocketMessage.fromJson(json);
          _logger.i('Received message: ${socketMessage.type}');

          // Handle REQ_JOIN
          if (socketMessage.type == 'REQ_JOIN') {
            final name = socketMessage.payload['name'] as String?;
            if (name != null) {
              _logger.i('Player joined: $name');
              // Send SYNC_MAP
              _sendSyncMap(client);
              // Broadcast player joined
              _broadcastMessage(SocketMessage(
                type: 'PLAYER_JOINED',
                payload: {'name': name},
              ));
            }
          } else if (socketMessage.type == 'CARD_FLIP') {
            final index = socketMessage.payload['index'] as int?;
            if (index != null && index >= 0 && index < 25) {
              _handleCardFlip(index);
            }
          }
        } catch (e) {
          _logger.e('Error parsing message: $e');
        }
      },
      onDone: () {
        _logger.i('Client disconnected');
        _clients.remove(client);
      },
      onError: (error) {
        _logger.e('Client error: $error');
        _clients.remove(client);
      },
    );
  }

  /// Sends SYNC_MAP to a specific client
  void _sendSyncMap(Socket client) {
    if (_gameCards != null) {
      final message = SocketMessage(
        type: 'SYNC_MAP',
        payload: {
          'cards': _gameCards,
          'currentTurn': 'red',
          'isGameOver': false,
        },
      );
      final json = jsonEncode(message.toJson());
      client.write(json);
      _logger.i('Sent SYNC_MAP to client');
    }
  }

  /// Handles card flip
  void _handleCardFlip(int index) {
    if (_gameCards != null) {
      _gameCards![index]['isRevealed'] = true;
      final color = _gameCards![index]['color'];
      // Broadcast updated state
      _broadcastMessage(SocketMessage(
        type: 'STATE_UPDATE',
        payload: {
          'cards': _gameCards,
          'currentTurn': 'red', // Update logic here
          'isGameOver': color == 'assassin',
        },
      ));
      _logger.i('Card flipped: $index, color: $color');
    }
  }

  /// Broadcasts a message to all connected clients
  void _broadcastMessage(SocketMessage message) {
    final json = jsonEncode(message.toJson());
    for (final client in _clients) {
      client.write(json);
    }
    _logger.i('Broadcasted message: ${message.type}');
  }

  /// Handles card flip (public for external access)
  void handleCardFlip(int index) {
    _handleCardFlip(index);
  }

  /// Stops the server
  void stopServer() {
    _serverSocket?.close();
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
    _logger.i('Server stopped');
  }
}