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
    ];
  }

  static Future<TestResult> _testHostLifecycle() async {
    final startTime = DateTime.now();
    final host = SocketHost();
    try {
      await host.startServer('TestHost');
      // Server started, now stop it
      host.stopServer();
      
      // Try starting again on same port (should work if port was released)
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
      
      // Connect to localhost (127.0.0.1)
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
}
