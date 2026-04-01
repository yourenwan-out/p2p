// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/appwrite/appwrite_providers.dart';
import '../../../../core/appwrite/appwrite_room_service.dart';

const _surface = Color(0xFF001429);
const _surfaceContainerLow = Color(0xFF001D36);
const _surfaceContainerHighest = Color(0xFF183655);
const _primary = Color(0xFFFFB77A);
const _primaryContainer = Color(0xFFF28E26);
const _secondary = Color(0xFF95CEEF);
const _secondaryContainer = Color(0xFF034F6B);
const _tertiary = Color(0xFFFFB5A0);
const _tertiaryContainer = Color(0xFFFF835F);
const _outline = Color(0xFFA38D7C);
const _outlineVariant = Color(0xFF554336);
const _onSurface = Color(0xFFD1E4FF);
const _onSurfaceVariant = Color(0xFFDBC2B0);

class MissionRoomScreen extends ConsumerStatefulWidget {
  final String? roomId;
  final bool isHost;

  const MissionRoomScreen({
    super.key,
    this.roomId,
    this.isHost = false,
  });

  @override
  ConsumerState<MissionRoomScreen> createState() => _MissionRoomScreenState();
}

class _MissionRoomScreenState extends ConsumerState<MissionRoomScreen> {
  bool _isLoading = true;
  String? _myId;
  Map<String, dynamic>? _roomData;
  RealtimeSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _initRoom();
  }

  Future<void> _initRoom() async {
    if (widget.roomId == null) return;
    try {
      final account = ref.read(appwriteAccountProvider);
      final user = await account.get();
      _myId = user.$id;

      await _fetchRoomData();

      final roomService = ref.read(appwriteRoomServiceProvider);
      _subscription = roomService.subscribeToRoom(widget.roomId!);
      _subscription!.stream.listen((event) {
        if (event.payload.isNotEmpty) {
          setState(() {
            _roomData = event.payload;
          });
          if (event.payload['status'] == 'active') {
             // Game started! Navigate to board logic
             _showSnack('بدأت المهمة!');
             // Navigator.push(...)
          }
        }
      });
    } catch (e) {
      _showSnack('خطأ في جلب الغرفة: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRoomData() async {
    final databases = ref.read(appwriteDatabasesProvider);
    final doc = await databases.getDocument(
      databaseId: AppwriteRoomService.databaseId,
      collectionId: AppwriteRoomService.roomsCollectionId,
      documentId: widget.roomId!,
    );
    if (mounted) {
      setState(() => _roomData = doc.data);
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  Future<void> _updateMyAgent(String team, String role) async {
    if (_myId == null || widget.roomId == null) return;
    try {
      final roomService = ref.read(appwriteRoomServiceProvider);
      await roomService.updatePlayer(widget.roomId!, _myId!, {
        'team': team,
        'role': role,
      });
    } catch (e) {
      _showSnack('فشل التحديث: $e');
    }
  }

  Future<void> _leaveRoom() async {
    if (_myId != null && widget.roomId != null) {
      try {
        await ref.read(appwriteRoomServiceProvider).leaveRoom(widget.roomId!, _myId!);
      } catch (e) {
        // Ignore leave errors
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _launchMission() async {
    if (!widget.isHost) return;
    try {
      await ref.read(appwriteRoomServiceProvider).startGame(widget.roomId!);
    } catch (e) {
      _showSnack('فشل بدء المهمة: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.notoSansArabic()),
      backgroundColor: _surfaceContainerHighest,
    ));
  }

  List<dynamic> get _players {
    if (_roomData == null || _roomData!['players'] == null) return [];
    return (_roomData!['players'] as List).map((p) => jsonDecode(p.toString())).toList();
  }

  Map<String, dynamic>? get _myPlayer {
    try {
      return _players.firstWhere((p) => p['id'] == _myId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: _surface, body: Center(child: CircularProgressIndicator(color: _primary)));
    }

    if (_roomData == null) {
      return Scaffold(
        backgroundColor: _surface,
        body: Center(
          child: Text('الغرفة غير موجودة أو انتهت', style: GoogleFonts.notoSansArabic(color: Colors.white, fontSize: 18)),
        ),
      );
    }

    final redTeam = _players.where((p) => p['team'] == 'red').toList();
    final blueTeam = _players.where((p) => p['team'] == 'blue').toList();
    final maxPlayers = _roomData!['max_players'] ?? 6;

    final myTeam = _myPlayer?['team'] ?? 'blue';
    final myRole = _myPlayer?['role'] ?? 'field_agent';

    final hasRedSpymaster = redTeam.any((p) => p['role'] == 'spymaster');
    final hasBlueSpymaster = blueTeam.any((p) => p['role'] == 'spymaster');
    final minClientsReached = _players.length >= 2;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          Positioned(top: 0, left: 0, right: 0, height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primary.withValues(alpha: 0.1), Colors.transparent],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  children: [
                    _buildRoomHeader(_roomData!['code'] ?? '-----'),
                    const SizedBox(height: 32),
                    _buildTeamSection('فريق التدخل الأحمر', redTeam, maxPlayers ~/ 2, _tertiary, _tertiaryContainer, Icons.local_fire_department),
                    const SizedBox(height: 24),
                    _buildTeamSection('فريق التدخل الأزرق', blueTeam, maxPlayers ~/ 2, _secondary, _secondaryContainer, Icons.ac_unit),
                    const SizedBox(height: 32),
                    _buildAgentSettings(myTeam, myRole),
                    const SizedBox(height: 32),
                    _buildLaunchControl(minClientsReached, hasRedSpymaster, hasBlueSpymaster),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
          
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildTeamSection(String title, List<dynamic> players, int max, Color baseColor, Color containerColor, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: containerColor),
                const SizedBox(width: 8),
                Text(title, style: GoogleFonts.spaceGrotesk(color: containerColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: containerColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
              child: Text('${players.length} / $max', style: GoogleFonts.spaceGrotesk(color: baseColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...players.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TeamPlayer(
            name: p['name'], 
            role: p['role'] == 'spymaster' ? 'رئيس الشبكة' : 'عميل ميداني', 
            isSpymaster: p['role'] == 'spymaster', 
            baseColor: baseColor, 
            containerColor: containerColor,
            isLocal: p['id'] == _myId,
          ),
        )),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _surface.withValues(alpha: 0.8),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.security, color: _primary, size: 22),
                const SizedBox(width: 8),
                Text('الأسماء الرمزية',
                  style: GoogleFonts.spaceGrotesk(
                    color: _primaryContainer, fontWeight: FontWeight.bold,
                    fontSize: 18, letterSpacing: 1.5)),
              ]),
              _pillButton(icon: Icons.favorite, label: 'إدعمنا'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillButton({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _primaryContainer.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: _primaryContainer, size: 16),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.notoSansArabic(
          color: _primaryContainer, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  Widget _buildRoomHeader(String code) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 8),
                  Text('الجهاز مؤمن', style: GoogleFonts.plusJakartaSans(color: _primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 4),
              Text('غرفة المهمة', style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('تم إنشاء اتصال مشفر. قم بتكوين فريق التدخل الخاص بك والاستعداد للانتشار.', 
                style: GoogleFonts.plusJakartaSans(color: _onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: const Border(right: BorderSide(color: _primary, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رمز الغرفة', style: GoogleFonts.plusJakartaSans(color: _outline, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('#$code', style: GoogleFonts.spaceGrotesk(color: _primary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildAgentSettings(String myTeam, String myRole) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('إعدادات العميل', style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text('اختر انتماء الفريق', style: GoogleFonts.plusJakartaSans(color: _outline, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _updateMyAgent('red', myRole),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: myTeam == 'red' ? _tertiaryContainer.withValues(alpha: 0.2) : _surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: myTeam == 'red' ? _tertiaryContainer : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: _tertiaryContainer, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text('أحمر', style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _updateMyAgent('blue', myRole),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: myTeam == 'blue' ? _secondaryContainer.withValues(alpha: 0.5) : _surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: myTeam == 'blue' ? _secondary : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: _secondary, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text('أزرق', style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('الدور التكتيكي', style: GoogleFonts.plusJakartaSans(color: _outline, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _outlineVariant, width: 2)),
              color: Color(0xFF000F20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: myRole,
                isExpanded: true,
                dropdownColor: _surfaceContainerLow,
                icon: const Icon(Icons.expand_more, color: _outlineVariant),
                style: GoogleFonts.notoSansArabic(color: _onSurface, fontSize: 14),
                onChanged: (val) {
                  if (val != null) _updateMyAgent(myTeam, val);
                },
                items: const [
                  DropdownMenuItem(value: 'field_agent', child: Text('عميل ميداني')),
                  DropdownMenuItem(value: 'spymaster', child: Text('رئيس الشبكة')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info, color: _primary, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('يقدم رؤساء الشبكة أدلة لفرقهم. مطلوب رئيس شبكة واحد على الأقل لكل فريق للانتشار.', 
                  style: GoogleFonts.notoSansArabic(color: _onSurfaceVariant, fontSize: 11))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLaunchControl(bool minClients, bool hasRedSpy, bool hasBlueSpy) {
    bool canLaunch = minClients && hasRedSpy && hasBlueSpy;

    return Column(
      children: [
        if (widget.isHost)
          GestureDetector(
            onTap: canLaunch ? _launchMission : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: canLaunch ? [_primary, _primaryContainer] : [Colors.grey.shade700, Colors.grey.shade800]),
                borderRadius: BorderRadius.circular(999),
                boxShadow: canLaunch ? [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))] : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('بدء المهمة', style: GoogleFonts.spaceGrotesk(color: canLaunch ? const Color(0xFF5D3100) : Colors.white54, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(width: 12),
                  Icon(Icons.rocket_launch, color: canLaunch ? const Color(0xFF5D3100) : Colors.white54),
                ],
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(color: _surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
            child: Center(
              child: Text('بانتظار مضيف الغرفة للبدء...', style: GoogleFonts.spaceGrotesk(color: _onSurfaceVariant, fontSize: 14)),
            ),
          ),
        
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _leaveRoom,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: _outlineVariant.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('الخروج من الغرفة', style: GoogleFonts.spaceGrotesk(color: _onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                const Icon(Icons.exit_to_app, color: _onSurfaceVariant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF000F20).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outlineVariant.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('جاهزية الانتشار', style: GoogleFonts.plusJakartaSans(color: _outline, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _CheckItem(text: 'الحد الأدنى من العملاء', isReady: minClients),
              const SizedBox(height: 8),
              _CheckItem(text: 'تم تعيين رئيس شبكة للفريق الأحمر', isReady: hasRedSpy),
              const SizedBox(height: 8),
              _CheckItem(text: 'تم تعيين رئيس شبكة للفريق الأزرق', isReady: hasBlueSpy),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: _outlineVariant.withValues(alpha: 0.12))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, -8))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(icon: Icons.login, label: 'الإنضمام', active: false),
              _navItem(icon: Icons.groups, label: 'الفريق', active: true),
              _navItem(icon: Icons.assignment, label: 'المهمة', active: false),
              _navItem(icon: Icons.history, label: 'LOGS', active: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: active ? BoxDecoration(
        color: _surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12)) : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: active ? _primary : _outlineVariant, size: 22),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.notoSansArabic(
          color: active ? _primary : _outlineVariant.withValues(alpha: 0.7),
          fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TeamPlayer extends StatelessWidget {
  final String name, role;
  final bool isSpymaster, isLocal;
  final Color baseColor, containerColor;

  const _TeamPlayer({
    required this.name, required this.role,
    required this.isSpymaster, required this.baseColor, required this.containerColor,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSpymaster) {
      return Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [containerColor, baseColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _surfaceContainerLow, borderRadius: BorderRadius.circular(11)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: _surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.person, color: _outlineVariant)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.spaceGrotesk(color: _onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(role, style: GoogleFonts.plusJakartaSans(color: baseColor, fontSize: 10, fontWeight: FontWeight.w800)),
                    ],
                  )
                ],
              ),
              Icon(Icons.verified_user, color: baseColor),
            ],
          ),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLocal ? _surfaceContainerHighest : _surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: isLocal ? Border.all(color: _primary.withValues(alpha: 0.5), width: 2) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: _surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.person, color: _outlineVariant)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.spaceGrotesk(color: isLocal ? _primary : _onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(role, style: GoogleFonts.plusJakartaSans(color: _onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w800)),
                ],
              )
            ],
          ),
          if (isLocal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text('محلي', style: GoogleFonts.plusJakartaSans(color: _primary, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  final bool isReady;
  const _CheckItem({required this.text, required this.isReady});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(isReady ? Icons.check_circle : Icons.radio_button_unchecked, color: isReady ? Colors.green : _outlineVariant, size: 14),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.notoSansArabic(color: isReady ? _onSurface : _onSurfaceVariant, fontSize: 12)),
      ],
    );
  }
}
