import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:p2p_codenames/core/network/connection_provider.dart';
import 'package:p2p_codenames/core/network/ip_utils.dart';
import 'package:p2p_codenames/core/utils/validators.dart';
import 'lobby_screen.dart';
import '../../testing/presentation/test_runner_screen.dart';

/// Start screen for the P2P Codenames app
/// Allows users to host a game or join an existing one
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  final TextEditingController _ipController = TextEditingController();
  final Logger _logger = Logger();
  late Box _settingsBox;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settingsBox');
    _loadLastIP();
  }

  void _loadLastIP() {
    final lastIP = _settingsBox.get('lastIP');
    if (lastIP != null) {
      _ipController.text = lastIP;
    }
  }

  void _saveLastIP(String ip) {
    _settingsBox.put('lastIP', ip);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _handleHostGame() async {
    final ip = await IPUtils.getIPAddress();
    if (!mounted) return;
    if (ip != null) {
      _logger.i('Hosting game with IP: $ip');
      ref.read(connectionProvider.notifier).startHosting();
      // Navigate to lobby
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LobbyScreen()),
      );
    } else {
      _logger.e('Failed to get IP address for hosting');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get IP address')),
      );
    }
  }

  void _handleJoinGame() {
    final ip = _ipController.text.trim();
    final validationError = Validators.validateIPAddress(ip);
    if (validationError != null) {
      _logger.w('Join game failed: $validationError');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }
    _logger.i('Joining game with IP: $ip');
    ref.read(connectionProvider.notifier).joinGame(ip, 'Player'); // TODO: Get player name
    _saveLastIP(ip); // Save successful IP
    // Navigate to lobby
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LobbyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'P2P Codenames',
          style: TextStyle(fontSize: 20.sp),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to P2P Codenames!',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40.h),
            ElevatedButton(
              onPressed: _handleHostGame,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50.h),
                textStyle: TextStyle(fontSize: 18.sp),
              ),
              child: const Text('Create Room (Host)'),
            ),
            SizedBox(height: 32.h),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'Enter IP Address',
                hintText: 'e.g., 192.168.1.100',
                border: const OutlineInputBorder(),
                errorText: Validators.validateIPAddress(_ipController.text.isEmpty ? null : _ipController.text),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: _handleJoinGame,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50.h),
                textStyle: TextStyle(fontSize: 18.sp),
              ),
              child: const Text('Join Game'),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TestRunnerScreen()),
          );
        },
        label: const Text('Self Test 🧪'),
        icon: const Icon(Icons.science),
        backgroundColor: Colors.purple.shade200,
      ),
    );
  }
}