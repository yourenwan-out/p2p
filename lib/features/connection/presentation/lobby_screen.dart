import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:p2p_codenames/core/network/connection_provider.dart';
import 'package:p2p_codenames/core/network/ip_utils.dart';
import 'package:p2p_codenames/features/game_board/presentation/game_board_screen.dart';
import 'package:p2p_codenames/features/game_board/models/player.dart';
import 'package:p2p_codenames/features/game_board/models/game_state.dart';

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

  void _handleStartGame(ConnectionState state) {
    if (state.players.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يكون هناك 4 لاعبين على الأقل لبدء اللعبة')),
      );
      return;
    }
    
    final hasRedSpymaster = state.players.any((p) => p.team == Team.red && p.role == Role.spymaster);
    final hasBlueSpymaster = state.players.any((p) => p.team == Team.blue && p.role == Role.spymaster);

    if (!hasRedSpymaster || !hasBlueSpymaster) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يكون لكل فريق رئيس شبكة واحد على الأقل')),
      );
      return;
    }

    ref.read(connectionProvider.notifier).startGame();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectionState>(connectionProvider, (previous, next) {
      if (next.isGameStarted && previous?.isGameStarted != true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GameBoardScreen()),
        );
      }
    });

    final connectionState = ref.watch(connectionProvider);
    
    Player? localPlayer;
    if (connectionState.localPlayerId != null) {
      try {
        localPlayer = connectionState.players.firstWhere((p) => p.id == connectionState.localPlayerId);
      } catch (e) {
        // Not found yet
      }
    }

    final redTeam = connectionState.players.where((p) => p.team == Team.red).toList();
    final blueTeam = connectionState.players.where((p) => p.team == Team.blue).toList();

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        ref.read(connectionProvider.notifier).disconnect();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('غرفة الانتظار', style: TextStyle(fontSize: 20.sp)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              ref.read(connectionProvider.notifier).disconnect();
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_hostIP != null)
              Text(
                'رقم غرفتك (IP): $_hostIP',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 16.h),
            
            // Local Player Setup
            if (localPlayer != null)
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    children: [
                      Text('إعداداتك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          DropdownButton<Team>(
                            value: localPlayer.team,
                            onChanged: (Team? newTeam) {
                              if (newTeam != null) {
                                ref.read(connectionProvider.notifier).updateLocalPlayer(newTeam, localPlayer!.role);
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: Team.red, child: Text('الفريق الأحمر')),
                              DropdownMenuItem(value: Team.blue, child: Text('الفريق الأزرق')),
                            ],
                          ),
                          DropdownButton<Role>(
                            value: localPlayer.role,
                            onChanged: (Role? newRole) {
                              if (newRole != null) {
                                ref.read(connectionProvider.notifier).updateLocalPlayer(localPlayer!.team, newRole);
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: Role.operative, child: Text('عميل ميداني')),
                              DropdownMenuItem(value: Role.spymaster, child: Text('رئيس شبكة 🔍')),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            SizedBox(height: 16.h),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Red Team List
                  Expanded(
                    child: Column(
                      children: [
                        Text('الفريق الأحمر', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18.sp)),
                        Expanded(
                          child: ListView.builder(
                            itemCount: redTeam.length,
                            itemBuilder: (context, index) {
                              final p = redTeam[index];
                              return ListTile(
                                title: Text(p.name, style: TextStyle(fontSize: 14.sp)),
                                subtitle: Text(p.role == Role.spymaster ? 'رئيس شبكة 🔍' : 'عميل ميداني', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                                dense: true,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, color: Colors.grey.shade300),
                  // Blue Team List
                  Expanded(
                    child: Column(
                      children: [
                        Text('الفريق الأزرق', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18.sp)),
                        Expanded(
                          child: ListView.builder(
                            itemCount: blueTeam.length,
                            itemBuilder: (context, index) {
                              final p = blueTeam[index];
                              return ListTile(
                                title: Text(p.name, style: TextStyle(fontSize: 14.sp)),
                                subtitle: Text(p.role == Role.spymaster ? 'رئيس شبكة 🔍' : 'عميل ميداني', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                                dense: true,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            if (connectionState.isHost)
              Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: ElevatedButton(
                  onPressed: () => _handleStartGame(connectionState),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50.h),
                    textStyle: TextStyle(fontSize: 18.sp),
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('بدء اللعبة'),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: Center(child: Text('بانتظار المضيف لبدء اللعبة...', style: TextStyle(fontSize: 16.sp, color: Colors.grey))),
              ),
              
            if (connectionState.error != null)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text('خطأ: ${connectionState.error}', style: TextStyle(color: Colors.red, fontSize: 14.sp), textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    ));
  }
}