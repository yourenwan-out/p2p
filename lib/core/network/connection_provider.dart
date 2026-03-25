import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../features/game_board/models/player.dart';
import '../../features/game_board/models/game_state.dart';
import '../../features/game_board/providers/game_provider.dart';
import 'models/socket_message.dart';
import 'socket_host.dart';
import 'socket_client.dart';

class ConnectionState {
  final bool isConnected;
  final bool isConnecting;
  final String? error;
  final List<Player> players;
  final String? localPlayerId;
  final bool isHost;
  final SocketHost? socketHost;
  final SocketClient? socketClient;

  const ConnectionState({
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
    this.players = const [],
    this.localPlayerId,
    this.isHost = false,
    this.socketHost,
    this.socketClient,
  });

  ConnectionState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? error,
    List<Player>? players,
    String? localPlayerId,
    bool? isHost,
    SocketHost? socketHost,
    SocketClient? socketClient,
  }) {
    return ConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
      players: players ?? this.players,
      localPlayerId: localPlayerId ?? this.localPlayerId,
      isHost: isHost ?? this.isHost,
      socketHost: socketHost ?? this.socketHost,
      socketClient: socketClient ?? this.socketClient,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  final Logger _logger = Logger();
  final Ref ref;

  ConnectionNotifier(this.ref) : super(const ConnectionState());

  Future<void> startHosting(String playerName) async {
    state = state.copyWith(isConnecting: true, error: null);
    try {
      final localId = 'host_${DateTime.now().millisecondsSinceEpoch}';
      final socketHost = SocketHost(
        onMessageReceived: _handleMessage,
        getGameState: () => ref.read(gameProvider),
      );
      await socketHost.startServer(playerName);
      state = state.copyWith(
        isConnected: true,
        isConnecting: false,
        localPlayerId: localId,
        isHost: true,
        socketHost: socketHost,
      );
      _logger.i('Hosting started successfully');
    } catch (e) {
      state = state.copyWith(error: e.toString(), isConnecting: false);
      _logger.e('Failed to start hosting: $e');
    }
  }

  Future<void> joinGame(String ip, String playerName) async {
    state = state.copyWith(isConnecting: true, error: null);
    try {
      final localId = 'player_${DateTime.now().millisecondsSinceEpoch}';
      final socketClient = SocketClient(
        onMessageReceived: _handleMessage, 
        localPlayerId: localId
      );
      await socketClient.connect(ip, playerName);
      state = state.copyWith(
        isConnected: true,
        isConnecting: false,
        localPlayerId: localId,
        isHost: false,
        socketClient: socketClient,
      );
      _logger.i('Joined game successfully');
    } catch (e) {
      state = state.copyWith(error: e.toString(), isConnecting: false);
      _logger.e('Failed to join game: $e');
    }
  }

  void setPlayers(List<Player> newPlayers) {
    state = state.copyWith(players: newPlayers);
    _logger.i('Players updated: ${newPlayers.length} players');
  }

  void setError(String error) {
    state = state.copyWith(error: error, isConnecting: false);
    _logger.e('Connection error: $error');
  }

  void disconnect() {
    state.socketHost?.stopServer();
    state.socketClient?.disconnect();
    state = const ConnectionState();
    _logger.i('Disconnected');
  }

  void _handleMessage(SocketMessage message) {
    if (message.type == 'LOBBY_UPDATE') {
      final playersJson = message.payload['players'] as List<dynamic>?;
      if (playersJson != null) {
        final newPlayers = playersJson
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList();
        setPlayers(newPlayers);
      }
    } else if (message.type == 'STATE_UPDATE') {
      // Client receiving updated game state
      if (!state.isHost) {
        ref.read(gameProvider.notifier).updateState(GameState.fromJson(message.payload));
      }
    } else if (state.isHost) {
      // Host processing game Actions
      if (message.type == 'CARD_FLIP') {
        final index = message.payload['index'] as int?;
        if (index != null) {
          ref.read(gameProvider.notifier).revealCard(index);
          state.socketHost?.broadcastGameState(ref.read(gameProvider));
        }
      } else if (message.type == 'CLUE_GIVEN') {
        final word = message.payload['word'] as String?;
        final number = message.payload['number'] as int?;
        if (word != null && number != null) {
          ref.read(gameProvider.notifier).giveClue(word, number);
          state.socketHost?.broadcastGameState(ref.read(gameProvider));
        }
      } else if (message.type == 'PASS_TURN') {
        ref.read(gameProvider.notifier).passTurn();
        state.socketHost?.broadcastGameState(ref.read(gameProvider));
      }
    }
  }

  void updateLocalPlayer(Team team, Role role) {
    if (state.localPlayerId == null) return;
    try {
      final localPlayer = state.players.firstWhere((p) => p.id == state.localPlayerId);
      final updatedPlayer = localPlayer.copyWith(team: team, role: role);

      if (state.isHost) {
        state.socketHost?.handlePlayerUpdate(updatedPlayer);
      } else {
        final message = SocketMessage(
          type: 'PLAYER_UPDATE',
          payload: {'player': updatedPlayer.toJson()},
        );
        state.socketClient?.sendMessage(message);
      }
    } catch (e) {
      _logger.e('Local player not found for update: $e');
    }
  }

  void sendCardFlip(int index) {
    final message = SocketMessage(type: 'CARD_FLIP', payload: {'index': index});
    if (state.isHost) {
      _handleMessage(message);
    } else {
      state.socketClient?.sendMessage(message);
    }
  }

  void sendClue(String word, int number) {
    final message = SocketMessage(type: 'CLUE_GIVEN', payload: {'word': word, 'number': number});
    if (state.isHost) {
      _handleMessage(message);
    } else {
      state.socketClient?.sendMessage(message);
    }
  }

  void sendPassTurn() {
    final message = SocketMessage(type: 'PASS_TURN', payload: {});
    if (state.isHost) {
      _handleMessage(message);
    } else {
      state.socketClient?.sendMessage(message);
    }
  }
}

final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionState>(
  (ref) => ConnectionNotifier(ref),
);