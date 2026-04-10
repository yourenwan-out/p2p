import 'dart:async';
import 'dart:convert';
import 'package:appwrite/appwrite.dart' hide Role;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../features/game_board/models/player.dart';
import '../../features/game_board/models/game_state.dart';
import '../../features/game_board/providers/game_provider.dart';
import '../appwrite/appwrite_room_service.dart';
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
  final bool isGameStarted;
  final SocketHost? socketHost;
  final SocketClient? socketClient;
  final String? appwriteRoomId;
  final RealtimeSubscription? appwriteSubscription;

  const ConnectionState({
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
    this.players = const [],
    this.localPlayerId,
    this.isHost = false,
    this.isGameStarted = false,
    this.socketHost,
    this.socketClient,
    this.appwriteRoomId,
    this.appwriteSubscription,
  });

  ConnectionState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? error,
    List<Player>? players,
    String? localPlayerId,
    bool? isHost,
    bool? isGameStarted,
    SocketHost? socketHost,
    SocketClient? socketClient,
    String? appwriteRoomId,
    RealtimeSubscription? appwriteSubscription,
  }) {
    return ConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
      players: players ?? this.players,
      localPlayerId: localPlayerId ?? this.localPlayerId,
      isHost: isHost ?? this.isHost,
      isGameStarted: isGameStarted ?? this.isGameStarted,
      socketHost: socketHost ?? this.socketHost,
      socketClient: socketClient ?? this.socketClient,
      appwriteRoomId: appwriteRoomId ?? this.appwriteRoomId,
      appwriteSubscription: appwriteSubscription ?? this.appwriteSubscription,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  final Logger _logger = Logger();
  final Ref ref;
  Timer? _heartbeatTimer;

  ConnectionNotifier(this.ref) : super(const ConnectionState());

  // === APPWRITE MULTIPLAYER ===

  void joinAppwriteGame(String localId, List<Player> initialPlayers, bool isHost, String roomId) {
    disconnect();

    // CRITICAL: Reset game board before joining for clients — prevents stale old board from showing
    if (!isHost) {
      ref.read(gameProvider.notifier).resetGame();
    }

    state = state.copyWith(
      isConnected: true,
      localPlayerId: localId,
      players: initialPlayers,
      isHost: isHost,
      isGameStarted: true,
      appwriteRoomId: roomId,
    );

    final roomService = ref.read(appwriteRoomServiceProvider);
    final subscription = roomService.subscribeToRoom(roomId);
    
    subscription.stream.listen((event) {
      if (event.payload.isNotEmpty) {
        final data = event.payload;
        
        // Sync Game State
        if (data['game_state'] != null) {
          final stateStr = data['game_state'] as String;
          if (stateStr.length > 5) {
             try {
                final gameStateJson = jsonDecode(stateStr);
                // We sync state from remote server for all clients
                ref.read(gameProvider.notifier).updateState(GameState.fromJson(gameStateJson));
             } catch(e) {
               _logger.e('Failed to parse Appwrite game_state: $e');
             }
          }
        }

        // Sync Players
        if (data['players'] != null) {
           try {
             final List<dynamic> pList = data['players'];
             final newPlayers = pList.map((p) => Player.fromJson(jsonDecode(p.toString()))).toList();
             setPlayers(newPlayers);
           } catch(e) {
             _logger.e('Failed to parse Appwrite players: $e');
           }
        }
      }
    });

    state = state.copyWith(appwriteSubscription: subscription);
    _logger.i('Joined Appwrite game successfully. Subscribed to Room: $roomId');

    // Start heartbeat timer: Updates last_activity every 60 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      try {
        ref.read(appwriteRoomServiceProvider).updateHeartbeat(roomId);
      } catch (e) {
        _logger.w('Heartbeat failed: $e');
      }
    });
  }

  Future<void> _pushGameStateToAppwrite() async {
    if (state.appwriteRoomId == null) return;
    try {
      final newState = ref.read(gameProvider).toJson();
      final jsonStr = jsonEncode(newState);
      await ref.read(appwriteRoomServiceProvider).updateGameState(state.appwriteRoomId!, jsonStr);
      _logger.i('Game state pushed to Appwrite.');
    } catch(e) {
      _logger.e('Failed to push to Appwrite: $e');
    }
  }

  // === LAN MULTIPLAYER ===

  Future<void> startHosting(String playerName) async {
    disconnect();
    state = state.copyWith(isConnecting: true, error: null);
    try {
      final localId = 'host_${DateTime.now().millisecondsSinceEpoch}';
      state = state.copyWith(localPlayerId: localId);

      final host = SocketHost(
        onMessageReceived: _handleMessage,
        getGameState: () => ref.read(gameProvider),
      );
      await host.startServer(playerName, localId);
      state = state.copyWith(
        isConnected: true,
        isConnecting: false,
        localPlayerId: localId,
        isHost: true,
        socketHost: host,
      );
      _logger.i('Hosting LAN started successfully');
    } catch (e) {
      state = state.copyWith(error: e.toString(), isConnecting: false);
      _logger.e('Failed to start LAN hosting: $e');
    }
  }

  Future<void> joinGame(String ip, String playerName) async {
    disconnect();
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
      _logger.i('Joined LAN game successfully');
    } catch (e) {
      state = state.copyWith(error: e.toString(), isConnecting: false);
      _logger.e('Failed to join LAN game: $e');
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    state.appwriteSubscription?.close();
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
      if (!state.isHost) {
        ref.read(gameProvider.notifier).updateState(GameState.fromJson(message.payload));
      }
    } else if (message.type == 'START_GAME') {
      state = state.copyWith(isGameStarted: true);
    } else if (state.isHost) {
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

      if (state.appwriteRoomId != null) {
        // Appwrite handles this via RoomServices directly in UI,
        // but we keep local state in sync just in case.
        return;
      }

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
    if (state.appwriteRoomId != null) {
      ref.read(gameProvider.notifier).revealCard(index);
      _pushGameStateToAppwrite();
      return;
    }

    final message = SocketMessage(type: 'CARD_FLIP', payload: {'index': index});
    if (state.isHost) {
      _handleMessage(message);
    } else {
      state.socketClient?.sendMessage(message);
    }
  }

  void sendClue(String word, int number) {
    if (state.appwriteRoomId != null) {
      ref.read(gameProvider.notifier).giveClue(word, number);
      _pushGameStateToAppwrite();
      return;
    }

    final message = SocketMessage(type: 'CLUE_GIVEN', payload: {'word': word, 'number': number});
    if (state.isHost) {
      _handleMessage(message);
    } else {
      state.socketClient?.sendMessage(message);
    }
  }

  void sendPassTurn() {
    if (state.appwriteRoomId != null) {
      ref.read(gameProvider.notifier).passTurn();
      _pushGameStateToAppwrite();
      return;
    }

    const message = SocketMessage(type: 'PASS_TURN', payload: {});
    if (state.isHost) {
      _handleMessage(message);
    } else {
      state.socketClient?.sendMessage(message);
    }
  }

  void startGame() {
    if (state.appwriteRoomId != null) {
      // Handled by AppwriteRoomService in MissionRoomScreen
      return;
    }

    if (state.isHost) {
      const message = SocketMessage(type: 'START_GAME', payload: {});
      _handleMessage(message);
      state.socketHost?.broadcastMessage(message);
    }
  }
}

final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionState>(
  (ref) => ConnectionNotifier(ref),
);