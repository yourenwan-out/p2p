import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:appwrite/appwrite.dart';

import '../../../../core/appwrite/appwrite_providers.dart';
import '../../../../core/appwrite/appwrite_room_service.dart';
import 'mission_room_screen.dart';
import 'widgets/custom_words_selector.dart';

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

class RoomSettingsScreen extends ConsumerStatefulWidget {
  const RoomSettingsScreen({super.key});

  @override
  ConsumerState<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends ConsumerState<RoomSettingsScreen> {
  bool _isPublic = true;
  int _redCount = 1;
  int _blueCount = 0;
  bool _isLoading = false;
  late String _roomCode;
  final TextEditingController _roomNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _roomCode = _generateRoomCode();
    // Guard: Hive may not be initialized if startup failed
    final lastName = Hive.isBoxOpen('settingsBox')
        ? Hive.box('settingsBox').get('lastName', defaultValue: 'العميل')
        : 'العميل';
    _roomNameController.text = 'غرفة $lastName';
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      5, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAndJoin() async {
    if (_redCount + _blueCount < 2) {
      _showSnack('يجب أن يكون الحد الأقصى للاعبين 2 على الأقل');
      return;
    }
    if (_roomNameController.text.trim().isEmpty) {
      _showSnack('يرجى إدخال اسم الغرفة');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Re-attempt session in case startup background attempt timed out
      await ref
          .read(authServiceProvider)
          .ensureAnonymousSession()
          .timeout(const Duration(seconds: 12));

      final account = ref.read(appwriteAccountProvider);
      final user = await account.get();
      final hostId = user.$id;

      // Guard: Hive may not be initialized if startup failed
      final hostName = Hive.isBoxOpen('settingsBox')
          ? Hive.box('settingsBox').get('lastName', defaultValue: 'Unknown')
          : _roomNameController.text.trim().isNotEmpty
              ? _roomNameController.text.trim()
              : 'Unknown';

      final roomService = ref.read(appwriteRoomServiceProvider);
      
      final roomId = await roomService.createRoom(
        hostId: hostId,
        hostName: hostName,
        roomName: _roomNameController.text.trim(),
        roomCode: _roomCode,
        isPublic: _isPublic,
        maxPlayers: _redCount + _blueCount,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => MissionRoomScreen(roomId: roomId, isHost: true))
        );
      }
    } on AppwriteException catch (e) {
      _showSnack('فشل إنشاء الغرفة: ${e.message}');
    } catch (e) {
      _showSnack('حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg) {
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
          Positioned(top: MediaQuery.of(context).size.height * 0.1, right: -60,
            child: _glowBlob(_primary.withValues(alpha: 0.08), 300)),
          
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  children: [
                    _buildScreenHeader(),
                    const SizedBox(height: 32),
                    _buildSecretCodeSection(),
                    const SizedBox(height: 32),
                    _buildTeamCountSection(),
                    const SizedBox(height: 32),
                    _buildRoomNameInput(),
                    const SizedBox(height: 24),
                    _buildPrivacySection(),
                    const SizedBox(height: 32),
                    const CustomWordsSelector(),
                    const SizedBox(height: 32),
                    _buildConfirmButton(),
                    const SizedBox(height: 100), // Bottom nav padding
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

  Widget _glowBlob(Color color, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 40)]),
  );

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

  Widget _buildScreenHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('إعدادات الغرفة', style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 32, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('تجهيز بروتوكول الاتصال السري', style: GoogleFonts.plusJakartaSans(color: _onSurfaceVariant, fontSize: 14)),
      ],
    );
  }

  Widget _buildSecretCodeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الرمز السري', style: GoogleFonts.spaceGrotesk(color: _primary.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
              Icon(Icons.fingerprint, color: _primary.withValues(alpha: 0.4)),
            ],
          ),
          const SizedBox(height: 16),
          Text(_roomCode, style: GoogleFonts.spaceGrotesk(color: _primary, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 8)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _roomCode));
              _showSnack('تم نسخ الرمز السري');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: _surfaceContainerHighest, borderRadius: BorderRadius.circular(999), border: Border.all(color: _primary.withValues(alpha: 0.2))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy, color: _primary, size: 14),
                  const SizedBox(width: 8),
                  Text('نسخ الرمز', style: GoogleFonts.plusJakartaSans(color: _primary, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTeamCountSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _tertiaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: const Border(right: BorderSide(color: _tertiary, width: 4)),
            ),
            child: Column(
              children: [
                Text('فريق التدخل الأحمر', style: GoogleFonts.spaceGrotesk(color: _tertiary.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('$_redCount', style: GoogleFonts.spaceGrotesk(color: _tertiary, fontSize: 40, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                _TeamCountButton(icon: Icons.keyboard_arrow_up, color: _tertiary, onTap: () => setState(() => _redCount++)),
                const SizedBox(height: 8),
                _TeamCountButton(icon: Icons.keyboard_arrow_down, color: _tertiary, onTap: () => setState(() { if (_redCount > 0) _redCount--; })),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _secondaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: const Border(right: BorderSide(color: _secondary, width: 4)),
            ),
            child: Column(
              children: [
                Text('فريق التدخل الأزرق', style: GoogleFonts.spaceGrotesk(color: _secondary.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('$_blueCount', style: GoogleFonts.spaceGrotesk(color: _secondary, fontSize: 40, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                _TeamCountButton(icon: Icons.keyboard_arrow_up, color: _secondary, onTap: () => setState(() => _blueCount++)),
                const SizedBox(height: 8),
                _TeamCountButton(icon: Icons.keyboard_arrow_down, color: _secondary, onTap: () => setState(() { if (_blueCount > 0) _blueCount--; })),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('اسم الغرفة', style: GoogleFonts.plusJakartaSans(color: _outlineVariant, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _roomNameController,
          style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF000F20),
            hintText: 'غرفة أحمد',
            hintStyle: TextStyle(color: _onSurfaceVariant.withValues(alpha: 0.3)),
            border: const UnderlineInputBorder(borderSide: BorderSide(color: _outline, width: 2)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _outline, width: 2)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _primary, width: 2)),
            suffixIcon: const Icon(Icons.edit, color: _outlineVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('خصوصية الغرفة', style: GoogleFonts.plusJakartaSans(color: _outlineVariant, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isPublic = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _isPublic ? _primary.withValues(alpha: 0.1) : _surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isPublic ? _primary : _outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.public, color: _isPublic ? _primary : _onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('غرفة عامة', style: GoogleFonts.plusJakartaSans(color: _isPublic ? _primary : _onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isPublic = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: !_isPublic ? _primary.withValues(alpha: 0.1) : _surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: !_isPublic ? _primary : _outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.lock, color: !_isPublic ? _primary : _onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('غرفة خاصة', style: GoogleFonts.plusJakartaSans(color: !_isPublic ? _primary : _onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleCreateAndJoin,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_primary, _primaryContainer]),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _isLoading 
            ? [const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF5D3100), strokeWidth: 2))]
            : [
                Text('تأكيد الإنشاء والانضمام', style: GoogleFonts.spaceGrotesk(color: const Color(0xFF5D3100), fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                const Icon(Icons.login, color: Color(0xFF5D3100)),
              ],
        ),
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
              _navItem(icon: Icons.login, label: 'الإنضمام', active: false),
              _navItem(icon: Icons.groups, label: 'الفريق', active: false),
              _navItem(icon: Icons.assignment, label: 'المهمة', active: true),
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

class _TeamCountButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TeamCountButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}
