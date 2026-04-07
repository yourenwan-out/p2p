import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/appwrite/appwrite_providers.dart';
import '../../../../core/appwrite/appwrite_room_service.dart';
import 'mission_room_screen.dart';

// ─── Design System Colors ────────────────────────────────────────────────────
const _surface = Color(0xFF001429);
const _surfaceContainerLow = Color(0xFF001D36);
const _surfaceContainerHighest = Color(0xFF183655);
const _primary = Color(0xFFFFB77A);
const _primaryContainer = Color(0xFFF28E26);
const _secondary = Color(0xFF95CEEF);
const _secondaryContainer = Color(0xFF034F6B);
const _tertiary = Color(0xFFFFB5A0);
const _tertiaryContainer = Color(0xFFFF835F);

const _outlineVariant = Color(0xFF554336);
const _onSurface = Color(0xFFD1E4FF);
const _onSurfaceVariant = Color(0xFFDBC2B0);
const _surfaceBright = Color(0xFF1D3B5A);

class PublicRoomsScreen extends ConsumerStatefulWidget {
  const PublicRoomsScreen({super.key});

  @override
  ConsumerState<PublicRoomsScreen> createState() => _PublicRoomsScreenState();
}

class _PublicRoomsScreenState extends ConsumerState<PublicRoomsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _publicRooms = [];
  final TextEditingController _codeController = TextEditingController();
  String? _myId;
  String? _myName;

  @override
  void initState() {
    super.initState();
    _myName = Hive.box('settingsBox').get('lastName', defaultValue: 'العميل');
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final account = ref.read(appwriteAccountProvider);
      final user = await account.get();
      _myId = user.$id;
      
      final roomService = ref.read(appwriteRoomServiceProvider);
      _publicRooms = await roomService.getPublicRooms();
    } catch (e) {
      _showSnack('فشل الاتصال بالشبكة العالمية');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final roomService = ref.read(appwriteRoomServiceProvider);
      final roomId = await roomService.getRoomByCode(code);
      if (roomId != null) {
        await roomService.joinRoom(roomId, _myId!, _myName!);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => MissionRoomScreen(roomId: roomId, isHost: false))
          );
        }
      } else {
        _showSnack('رمز الغرفة غير صحيح أو المهمة قد بدأت مسبقاً');
      }
    } catch (e) {
      _showSnack('تعذر الانضمام: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom(String roomId) async {
    setState(() => _isLoading = true);
    try {
      final roomService = ref.read(appwriteRoomServiceProvider);
      await roomService.joinRoom(roomId, _myId!, _myName!);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MissionRoomScreen(roomId: roomId, isHost: false))
        );
      }
    } catch (e) {
      _showSnack('تعذر الانضمام للغرفة: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.notoSansArabic()),
      backgroundColor: _surfaceContainerHighest,
    ));
  }

  @override
  Widget build(BuildContext context) {
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
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  color: _primary,
                  backgroundColor: _surfaceContainerHighest,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    children: [
                      _buildHeroSection(),
                      const SizedBox(height: 32),
                      _buildJoinByCodeSection(),
                      const SizedBox(height: 32),
                      _buildPublicRoomsSection(),
                      const SizedBox(height: 32),
                      _buildDynamicTip(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
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

  Widget _buildHeroSection() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _surfaceContainerLow,
        image: const DecorationImage(
          image: AssetImage('assets/images/header_bg.png'),
          fit: BoxFit.cover,
        ),
        border: Border.all(color: _primary.withValues(alpha: 0.1)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [_surface, Colors.transparent],
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24, left: 24, right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('GLOBAL NETWORK', style: GoogleFonts.spaceGrotesk(
                    color: _primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                const SizedBox(height: 8),
                Text('مركز العمليات الميدانية', style: GoogleFonts.spaceGrotesk(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinByCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Text('الدخول برمز المشفر', style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.vpn_key, color: _outlineVariant),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'أدخل كود الغرفة',
                    hintStyle: GoogleFonts.notoSansArabic(color: _onSurfaceVariant.withValues(alpha: 0.4)),
                  ),
                  style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 16, letterSpacing: 2),
                ),
              ),
              GestureDetector(
                onTap: _isLoading ? null : _joinByCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_primary, _primaryContainer]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFF5D3100), strokeWidth: 2))
                      : Text('انضمام', style: GoogleFonts.notoSansArabic(color: const Color(0xFF5D3100), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPublicRoomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 4, height: 24, decoration: BoxDecoration(color: _secondary, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 12),
                Text('الغرف المتاحة', style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: _surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
              child: Text('${_publicRooms.length} غرفة نشطة', style: GoogleFonts.notoSansArabic(color: _onSurfaceVariant, fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_isLoading && _publicRooms.isEmpty)
           const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: _primary)))
        else if (_publicRooms.isEmpty)
           Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('لا توجد غرف عامة حالياً. كن أول من ينشئ مهمة!', style: GoogleFonts.notoSansArabic(color: _outlineVariant))))
        else
          ..._publicRooms.map((room) {
             List<dynamic> players = (room['players'] as List? ?? []).map((p) => jsonDecode(p.toString())).toList();
             int currentPlayers = players.length;
             int maxPlayers = room['max_players'] ?? 6;
             
             return Padding(
               padding: const EdgeInsets.only(bottom: 12),
               child: _RoomItem(
                 title: room['name'] ?? 'غرفة سرية',
                 icon: Icons.radar, 
                 iconColor: _secondary,
                 players: '$currentPlayers/$maxPlayers',
                 shields: 'مفعل',
                 verified: room['host_name'] ?? 'محلل مجهول',
                 isVip: currentPlayers >= maxPlayers, // example condition
                 onJoin: () => currentPlayers < maxPlayers ? _joinRoom(room['id']) : _showSnack('الغرفة ممتلئة'),
               ),
             );
          }),
      ],
    );
  }

  Widget _buildDynamicTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF000F20),
        borderRadius: BorderRadius.circular(12),
        border: const Border(right: BorderSide(color: _primary, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: _primary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.notoSansArabic(color: _onSurfaceVariant, fontSize: 13, height: 1.5),
                children: [
                  TextSpan(text: 'نصيحة تقنية: ', style: GoogleFonts.notoSansArabic(color: _onSurface, fontWeight: FontWeight.bold)),
                  const TextSpan(text: 'تأكد من استلام رمز التشفير الصحيح من قائد الفريق قبل المحاولة. الغرف العامة مفتوحة للجميع، لكن الغرف الخاصة تتطلب مصادقة ثنائية.'),
                ],
              ),
            ),
          ),
        ],
      ),
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
              _navItem(icon: Icons.login, label: 'الإنضمام', active: true),
              _navItem(icon: Icons.groups, label: 'الفريق', active: false),
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

class _RoomItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String players, shields, verified;
  final bool isVip;
  final VoidCallback onJoin;

  const _RoomItem({
    required this.title, required this.icon, required this.iconColor,
    required this.players, required this.shields, required this.verified,
    required this.onJoin,
    this.isVip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isVip ? Border(right: BorderSide(color: _primary.withValues(alpha: 0.4), width: 4)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: _surfaceBright, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: GoogleFonts.notoSansArabic(color: _onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                    if (isVip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text('ممتلئة', style: GoogleFonts.spaceGrotesk(color: _primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.groups, color: _onSurfaceVariant, size: 14),
                    const SizedBox(width: 4),
                    Text(players, style: GoogleFonts.spaceGrotesk(color: _onSurfaceVariant, fontSize: 12)),
                    const SizedBox(width: 12),
                    _StatBadge(icon: Icons.shield, value: shields, color: _tertiary, bgColor: _tertiaryContainer.withValues(alpha: 0.1)),
                    const SizedBox(width: 8),
                    _StatBadge(icon: Icons.person_pin, value: verified, color: _secondary, bgColor: _secondaryContainer.withValues(alpha: 0.1)),
                  ],
                )
              ],
            ),
          ),
          GestureDetector(
            onTap: onJoin,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(color: _surfaceBright, borderRadius: BorderRadius.circular(10)),
              child: Text('انضم', style: GoogleFonts.notoSansArabic(color: _onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color, bgColor;

  const _StatBadge({required this.icon, required this.value, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(value, style: GoogleFonts.notoSansArabic(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
