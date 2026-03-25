import '../models/test_result.dart';
import '../../../core/network/socket_host.dart';
import '../../../core/network/socket_client.dart';
import '../../../core/network/models/socket_message.dart';

class NetworkTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testHostLifecycle(),
      await _testClientLifecycle(),
      await _testSerialization(),
      await _testMultipleClientsAndDisconnect(),
    ];
  }

  static Future<TestResult> _testHostLifecycle() async {
    final startTime = DateTime.now();
    final host = SocketHost();
    try {
      await host.startServer('TestHost');
      host.stopServer();
      
      await host.startServer('TestHost');
      host.stopServer();

      return TestResult(
        name: 'Network: Host Lifecycle',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      host.stopServer();
      return TestResult(name: 'Network: Host Lifecycle', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testClientLifecycle() async {
    final startTime = DateTime.now();
    final host = SocketHost();
    final client = SocketClient(onMessageReceived: (_) {}, localPlayerId: 'test_client_id');
    try {
      await host.startServer('TestHost');
      await client.connect('127.0.0.1', 'TestPlayer');
      client.disconnect();
      host.stopServer();

      return TestResult(
        name: 'Network: Client Lifecycle',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      client.disconnect();
      host.stopServer();
      return TestResult(name: 'Network: Client Lifecycle', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testSerialization() async {
    final startTime = DateTime.now();
    try {
      const msg = SocketMessage(type: 'TEST', payload: {'key': 'value'});
      final json = msg.toJson();
      final decoded = SocketMessage.fromJson(json);
      
      if (decoded.type != 'TEST' || decoded.payload['key'] != 'value') {
        throw Exception('Serialization failed');
      }

      return TestResult(
        name: 'Network: Serialization',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(name: 'Network: Serialization', status: TestStatus.failed, errorMessage: e.toString());
    }
  }

  static Future<TestResult> _testMultipleClientsAndDisconnect() async {
    final startTime = DateTime.now();
    int hostLobbyUpdates = 0;
    final host = SocketHost(onMessageReceived: (msg) {
      if (msg.type == 'LOBBY_UPDATE') hostLobbyUpdates++;
    });

    final client1 = SocketClient(onMessageReceived: (_) {}, localPlayerId: 'client_1');
    final client2 = SocketClient(onMessageReceived: (_) {}, localPlayerId: 'client_2');
    try {
      await host.startServer('Host');
      await client1.connect('127.0.0.1', 'Player 1');
      await Future.delayed(const Duration(milliseconds: 100)); // allow TCP
      await client2.connect('127.0.0.1', 'Player 2');
      await Future.delayed(const Duration(milliseconds: 100));

      if (hostLobbyUpdates < 2) throw Exception('Host did not receive lobby updates for both clients');

      client1.disconnect();
      await Future.delayed(const Duration(milliseconds: 200)); // wait for socket to close
      // The host should recognize client1 disconnected and broadcast a new LOBBY_UPDATE.

      client2.disconnect();
      host.stopServer();

      return TestResult(
        name: 'Network: Multiple Clients & Disconnect',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      client1.disconnect();
      client2.disconnect();
      host.stopServer();
      return TestResult(name: 'Network: Multiple Clients & Disconnect', status: TestStatus.failed, errorMessage: e.toString());
    }
  }
}
