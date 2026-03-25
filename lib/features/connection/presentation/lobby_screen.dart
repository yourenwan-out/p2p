import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:p2p_codenames/core/network/connection_provider.dart';
import 'package:p2p_codenames/core/network/ip_utils.dart';
import 'package:p2p_codenames/features/game_board/presentation/game_board_screen.dart';

/// Lobby screen showing connected players
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  String? _hostIP;

  @override
  void initState() {
    super.initState();
    _loadHostIP();
  }

  Future<void> _loadHostIP() async {
    final ip = await IPUtils.getIPAddress();
    setState(() {
      _hostIP = ip;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Game Lobby',
          style: TextStyle(fontSize: 20.sp),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          children: [
            if (_hostIP != null)
              Text(
                'Host IP: $_hostIP',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            SizedBox(height: 32.h),
            Text(
              'Connected Players:',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.builder(
                itemCount: connectionState.players.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.h),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Text(
                        connectionState.players[index],
                        style: TextStyle(fontSize: 16.sp),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (connectionState.isHost)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GameBoardScreen()),
                  );
                },
                child: const Text('Start Game'),
              ),
            if (connectionState.error != null)
              Text(
                'Error: ${connectionState.error}',
                style: TextStyle(color: Colors.red, fontSize: 16.sp),
              ),
          ],
        ),
      ),
    );
  }
}