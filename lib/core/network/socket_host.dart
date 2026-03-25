import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import '../../features/game_board/models/player.dart';
import '../../features/game_board/models/game_state.dart';
import '../../features/game_board/models/word_card.dart';
import 'models/socket_message.dart';

class SocketHost {
  static const int port = 4567;
  ServerSocket? _serverSocket;
  final List<Socket> _clients = [];
  final Map<String, Socket> _clientSockets = {};
  final Function(SocketMessage)? onMessageReceived;
  final GameState Function()? getGameState;
  List<Player> _players = [];
  final Logger _logger = Logger();

  SocketHost({this.onMessageReceived, this.getGameState});

  Future<void> startServer(String hostName, String hostId) async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
      _logger.i('Server started on port $port');

      _players = [
        Player(
          id: hostId,
          name: hostName,
          team: Team.red,
          role: Role.spymaster,
          isHost: true,
        )
      ];
      _broadcastLobbyUpdate();

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

  void _handleClient(Socket client) {
    client.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      (message) {
        try {
          if (message.isEmpty) return;
          final json = jsonDecode(message) as Map<String, dynamic>;
          final socketMessage = SocketMessage.fromJson(json);
          _logger.i('Received message: ${socketMessage.type}');

          if (socketMessage.type == 'REQ_JOIN') {
            final id = socketMessage.payload['id'] as String?;
            final name = socketMessage.payload['name'] as String?;
            final teamStr = socketMessage.payload['team'] as String?;
            final roleStr = socketMessage.payload['role'] as String?;
            
            if (id != null && name != null && teamStr != null && roleStr != null) {
              _logger.i('Player joined: $name');
              _clientSockets[id] = client;
              
              final isRed = teamStr == 'red';
              final isSpymaster = roleStr == 'spymaster';
              
              Role finalRole = isSpymaster ? Role.spymaster : Role.operative;
              if (isSpymaster) {
                final teamPlayers = _players.where((p) => p.team == (isRed ? Team.red : Team.blue));
                if (teamPlayers.any((p) => p.role == Role.spymaster)) {
                  finalRole = Role.operative;
                }
              }

              final newPlayer = Player(
                id: id,
                name: name,
                team: isRed ? Team.red : Team.blue,
                role: finalRole,
                isHost: false,
              );
              
              _players.add(newPlayer);
              _broadcastLobbyUpdate();

              // Send initial state to the new player
              final currentState = getGameState?.call();
              if (currentState != null) {
                _sendGameStateToPlayer(newPlayer, currentState, client);
              }
            }
          } else if (socketMessage.type == 'PLAYER_UPDATE') {
            final updatedPlayerJson = socketMessage.payload['player'] as Map<String, dynamic>?;
            if (updatedPlayerJson != null) {
              final updatedPlayer = Player.fromJson(updatedPlayerJson);
              handlePlayerUpdate(updatedPlayer);
            }
          } else {
            // Other events (CARD_FLIP, CLUE_GIVEN) go straight to local UI
            onMessageReceived?.call(socketMessage);
          }
        } catch (e) {
          _logger.e('Error parsing message: $e');
        }
      },
      onError: (error) {
        _logger.e('Client error: $error');
        _handleDisconnect(client);
      },
    );
  }

  void _handleDisconnect(Socket client) {
    _clients.remove(client);
    String? disconnectedId;
    _clientSockets.forEach((key, value) {
      if (value == client) disconnectedId = key;
    });

    if (disconnectedId != null) {
      _players.removeWhere((p) => p.id == disconnectedId);
      _clientSockets.remove(disconnectedId);
      _broadcastLobbyUpdate();
      _logger.i('Player $disconnectedId disconnected, removed from lobby');
    }
  }

  void _broadcastLobbyUpdate() {
    final message = SocketMessage(
      type: 'LOBBY_UPDATE',
      payload: {'players': _players.map((p) => p.toJson()).toList()},
    );
    broadcastMessage(message);
    onMessageReceived?.call(message);
  }

  void broadcastGameState(GameState state) {
    for (final player in _players) {
      if (player.isHost) continue;
      final socket = _clientSockets[player.id];
      if (socket != null) {
        _sendGameStateToPlayer(player, state, socket);
      }
    }
  }

  void _sendGameStateToPlayer(Player player, GameState state, Socket socket) {
    GameState playerState = state;
    if (player.role == Role.operative) {
      final redactedCards = state.cards.map((c) {
        if (!c.isRevealed) {
          return c.copyWith(color: CardColor.neutral);
        }
        return c;
      }).toList();
      playerState = state.copyWith(cards: redactedCards);
    }
    
    final message = SocketMessage(
      type: 'STATE_UPDATE',
      payload: playerState.toJson(),
    );
    socket.write('${jsonEncode(message.toJson())}\n');
  }

  void broadcastMessage(SocketMessage message) {
    final json = jsonEncode(message.toJson());
    for (final client in _clients) {
      client.write('$json\n');
    }
    _logger.i('Broadcasted message: ${message.type}');
  }

  void handlePlayerUpdate(Player player) {
    Role finalRole = player.role;
    if (finalRole == Role.spymaster) {
      final teamPlayers = _players.where((p) => p.team == player.team && p.id != player.id);
      if (teamPlayers.any((p) => p.role == Role.spymaster)) {
        finalRole = Role.operative;
      }
    }

    final index = _players.indexWhere((p) => p.id == player.id);
    if (index != -1) {
      _players[index] = player.copyWith(role: finalRole);
      _broadcastLobbyUpdate();
      
      // If a player became a spymaster, they need the unredacted state
      final currentState = getGameState?.call();
      if (currentState != null) {
        final socket = _clientSockets[player.id];
        if (socket != null) {
          _sendGameStateToPlayer(_players[index], currentState, socket);
        }
      }
    }
  }

  void stopServer() {
    _serverSocket?.close();
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
    _clientSockets.clear();
    _logger.i('Server stopped');
  }
}