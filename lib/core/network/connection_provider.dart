import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'models/socket_message.dart';
import 'socket_host.dart';
import 'socket_client.dart';

/// State for connection management
class ConnectionState {
  final bool isConnected;
  final bool isConnecting;
  final String? error;
  final List<String> players;
  final bool isHost;
  final SocketHost? socketHost;
  final SocketClient? socketClient;

  const ConnectionState({
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
    this.players = const [],
    this.isHost = false,
    this.socketHost,
    this.socketClient,
  });

  ConnectionState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? error,
    List<String>? players,
    bool? isHost,
    SocketHost? socketHost,
    SocketClient? socketClient,
  }) {
    return ConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
      players: players ?? this.players,
      isHost: isHost ?? this.isHost,
      socketHost: socketHost ?? this.socketHost,
      socketClient: socketClient ?? this.socketClient,
    );
  }
}

/// Notifier for managing connection state
class ConnectionNotifier extends StateNotifier<ConnectionState> {
  final Logger _logger = Logger();

  ConnectionNotifier() : super(const ConnectionState());

  /// Starts hosting a game
  Future<void> startHosting() async {
    state = state.copyWith(isConnecting: true, error: null);
    try {
      final socketHost = SocketHost();
      await socketHost.startServer();
      state = state.copyWith(
        isConnected: true,
        isConnecting: false,
        isHost: true,
        socketHost: socketHost,
      );
      _logger.i('Hosting started successfully');
    } catch (e) {
      state = state.copyWith(error: e.toString(), isConnecting: false);
      _logger.e('Failed to start hosting: $e');
    }
  }

  /// Joins a game at the given IP
  Future<void> joinGame(String ip, String playerName) async {
    state = state.copyWith(isConnecting: true, error: null);
    try {
      final socketClient = SocketClient();
      await socketClient.connect(ip, playerName);
      state = state.copyWith(
        isConnected: true,
        isConnecting: false,
        isHost: false,
        socketClient: socketClient,
      );
      _logger.i('Joined game successfully');
    } catch (e) {
      state = state.copyWith(error: e.toString(), isConnecting: false);
      _logger.e('Failed to join game: $e');
    }
  }

  /// Adds a player to the list
  void addPlayer(String name) {
    final updatedPlayers = [...state.players, name];
    state = state.copyWith(players: updatedPlayers);
    _logger.i('Player added: $name');
  }

  /// Sets an error
  void setError(String error) {
    state = state.copyWith(error: error, isConnecting: false);
    _logger.e('Connection error: $error');
  }

  /// Disconnects
  void disconnect() {
    state.socketHost?.stopServer();
    state.socketClient?.disconnect();
    state = const ConnectionState();
    _logger.i('Disconnected');
  }

  /// Sends a card flip event
  void sendCardFlip(int index) {
    if (state.isHost) {
      // Host handles locally
      state.socketHost?.handleCardFlip(index);
    } else {
      // Client sends to host
      final message = SocketMessage(
        type: 'CARD_FLIP',
        payload: {'index': index},
      );
      state.socketClient?.sendMessage(message);
    }
  }
}

/// Provider for connection state
final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionState>(
  (ref) => ConnectionNotifier(),
);