// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'appwrite_providers.dart';

final appwriteRoomServiceProvider = Provider<AppwriteRoomService>((ref) {
  final databases = ref.watch(appwriteDatabasesProvider);
  final realtime = ref.watch(appwriteRealtimeProvider);
  return AppwriteRoomService(databases, realtime);
});

class AppwriteRoomService {
  final Databases _databases;
  final Realtime _realtime;

  static const String databaseId = '69ccd7f90036a2e58f2c';
  static const String roomsCollectionId = 'rooms';

  AppwriteRoomService(this._databases, this._realtime);

  Future<String> createRoom({
    required String hostId,
    required String hostName,
    required String roomName,
    required String roomCode,
    required bool isPublic,
    required int maxPlayers,
  }) async {
    final hostPlayer = {
      'id': hostId,
      'name': hostName,
      'team': 'red',
      'role': 'field_agent',
      'is_host': true,
    };

    try {
      final document = await _databases.createDocument(
        databaseId: databaseId,
        collectionId: roomsCollectionId,
        documentId: ID.unique(),
        data: {
          'name': roomName,
          'code': roomCode,
          'host_name': hostName,
          'status': 'waiting',
          'is_public': isPublic,
          'max_players': maxPlayers,
          'players': [jsonEncode(hostPlayer)],
          'game_state': '{}',
        },
      );
      return document.$id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> joinRoom(String roomId, String playerId, String playerName) async {
    try {
      final document = await _databases.getDocument(
        databaseId: databaseId,
        collectionId: roomsCollectionId,
        documentId: roomId,
      );

      List<String> playersDynamic = List<String>.from(document.data['players'] ?? []);
      
      // Check if player already exists
      bool exists = playersDynamic.any((p) {
        final Map<String, dynamic> decoded = jsonDecode(p);
        return decoded['id'] == playerId;
      });

      if (!exists) {
        final newPlayer = {
          'id': playerId,
          'name': playerName,
          'team': 'blue', // Default
          'role': 'field_agent',
          'is_host': false,
        };
        playersDynamic.add(jsonEncode(newPlayer));

        await _databases.updateDocument(
          databaseId: databaseId,
          collectionId: roomsCollectionId,
          documentId: roomId,
          data: {
            'players': playersDynamic,
          },
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePlayer(String roomId, String playerId, Map<String, dynamic> updates) async {
    try {
      final document = await _databases.getDocument(
        databaseId: databaseId,
        collectionId: roomsCollectionId,
        documentId: roomId,
      );

      List<String> playersDynamic = List<String>.from(document.data['players'] ?? []);
      bool changed = false;

      for (int i = 0; i < playersDynamic.length; i++) {
        final Map<String, dynamic> decoded = jsonDecode(playersDynamic[i]);
        if (decoded['id'] == playerId) {
          decoded.addAll(updates);
          playersDynamic[i] = jsonEncode(decoded);
          changed = true;
          break;
        }
      }

      if (changed) {
        await _databases.updateDocument(
          databaseId: databaseId,
          collectionId: roomsCollectionId,
          documentId: roomId,
          data: {
            'players': playersDynamic,
          },
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveRoom(String roomId, String playerId) async {
    try {
      final document = await _databases.getDocument(
        databaseId: databaseId,
        collectionId: roomsCollectionId,
        documentId: roomId,
      );

      List<String> playersDynamic = List<String>.from(document.data['players'] ?? []);
      
      playersDynamic.removeWhere((p) {
        final Map<String, dynamic> decoded = jsonDecode(p);
        return decoded['id'] == playerId;
      });

      if (playersDynamic.isEmpty) {
        // Delete room if empty
        await _databases.deleteDocument(
          databaseId: databaseId,
          collectionId: roomsCollectionId,
          documentId: roomId,
        );
      } else {
        await _databases.updateDocument(
          databaseId: databaseId,
          collectionId: roomsCollectionId,
          documentId: roomId,
          data: {
            'players': playersDynamic,
          },
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> startGame(String roomId) async {
    try {
      await _databases.updateDocument(
        databaseId: databaseId,
        collectionId: roomsCollectionId,
        documentId: roomId,
        data: {
          'status': 'active',
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateGameState(String roomId, String gameStateJson) async {
    try {
      await _databases.updateDocument(
        databaseId: databaseId,
        collectionId: roomsCollectionId,
        documentId: roomId,
        data: {
          'game_state': gameStateJson,
        },
      );
    } catch (e) {
      // Ignored to prevent UI crashes if some packets fail
    }
  }

  Future<List<Map<String, dynamic>>> getPublicRooms() async {
    try {
      final res = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: roomsCollectionId,
        queries: [
          Query.equal('is_public', true),
          Query.equal('status', 'waiting'),
          Query.orderDesc('\$createdAt'),
        ],
      );
      return res.documents.map((d) {
        final map = Map<String, dynamic>.from(d.data);
        map['id'] = d.$id;
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String?> getRoomByCode(String code) async {
    try {
      final res = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: roomsCollectionId,
        queries: [
          Query.equal('code', code),
          Query.equal('status', 'waiting'),
        ],
      );
      if (res.documents.isNotEmpty) {
        return res.documents.first.$id;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  RealtimeSubscription subscribeToRoom(String roomId) {
    return _realtime.subscribe([
      'databases.$databaseId.collections.$roomsCollectionId.documents.$roomId'
    ]);
  }
}
