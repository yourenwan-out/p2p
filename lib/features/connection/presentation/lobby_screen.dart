import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:p2p_codenames/core/network/connection_provider.dart';
import 'package:p2p_codenames/core/network/ip_utils.dart';
import 'package:p2p_codenames/features/game_board/presentation/game_board_screen.dart';
import 'package:p2p_codenames/features/game_board/models/player.dart';
import 'package:p2p_codenames/features/game_board/models/game_state.dart';

// ─── Design System Colors ─────────────────────────────────────────────────────
const _surface = Color(0xFF001429);
const _surfaceContainerLow = Color(0xFF001D36);
const _surfaceContainerHigh = Color(0xFF092B4A);
const _surfaceContainerHighest = Color(0xFF183655);
const _surfaceContainerLowest = Color(0xFF000F20);
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
const _onPrimaryContainer = Color(0xFF5D3100);

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
    setState(() => _hostIP = ip);
  }

  void _handleStartGame(ConnectionState state) {
    if (state.players.length < 4) {
      _showSnack('يجب أن يكون هناك 4 لاعبين على الأقل لبدء اللعبة');
      return;
    }
    final hasRedSpymaster = state.players.any((p) => p.team == Team.red && p.role == Role.spymaster);
    final hasBlueSpymaster = state.players.any((p) => p.team == Team.blue && p.role == Role.spymaster);
    if (!hasRedSpymaster || !hasBlueSpymaster) {
      _showSnack('يجب أن يكون لكل فريق رئيس شبكة واحد على الأقل');
      return;
    }
    ref.read(connectionProvider.notifier).startGame();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.notoSansArabic()),
      backgroundColor: _surfaceContainerHighest,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectionState>(connectionProvider, (previous, next) {
      if (next.isGameStarted && previous?.isGameStarted != true) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const GameBoardScreen()));
      }
    });

    final connectionState = ref.watch(connectionProvider);

    Player? localPlayer;
    if (connectionState.localPlayerId != null) {
      try {
        localPlayer = connectionState.players.firstWhere((p) => p.id == connectionState.localPlayerId);
      } catch (_) {}
    }

    final redTeam = connectionState.players.where((p) => p.team == Team.red).toList();
    final blueTeam = connectionState.players.where((p) => p.team == Team.blue).toList();

    // Readiness checks
    final hasEnough = connectionState.players.length >= 4;
    final hasRedSpy = redTeam.any((p) => p.role == Role.spymaster);
    final hasBluespy = blueTeam.any((p) => p.role == Role.spymaster);

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        ref.read(connectionProvider.notifier).disconnect();
        return true;
      },
      child: Scaffold(
        backgroundColor: _surface,
        body: Stack(
          children: [
            // Ambient glows
            Positioned(top: -80, right: -80,
              child: _glow(_primary.withValues(alpha: 0.05), 350)),
            Positioned(bottom: -80, left: -80,
              child: _glow(_secondary.withValues(alpha: 0.04), 300)),

            Column(
              children: [
                _buildHeader(connectionState),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          if (_hostIP != null) _buildIPCard(),
                          const SizedBox(height: 20),
                          // Teams row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildTeamColumn(
                                team: Team.red, players: redTeam,
                                label: 'فريق التدخل الأحمر',
                                accentColor: _tertiaryContainer,
                                headerColor: _tertiaryContainer,
                                badgeColor: _tertiary,
                                badgeBg: _tertiaryContainer.withValues(alpha: 0.2),
                                icon: Icons.local_fire_department,
                              )),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTeamColumn(
                                team: Team.blue, players: blueTeam,
                                label: 'فريق التدخل الأزرق',
                                accentColor: _secondary,
                                headerColor: _secondary,
                                badgeColor: _secondary,
                                badgeBg: _secondary.withValues(alpha: 0.2),
                                icon: Icons.ac_unit,
                                localPlayer: localPlayer,
                              )),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Settings card
                          if (localPlayer != null)
                            _buildSettingsCard(localPlayer, connectionState),
                          const SizedBox(height: 20),
                          // Start button or waiting
                          if (connectionState.isHost)
                            _buildLaunchSection(connectionState, hasEnough, hasRedSpy, hasBluespy)
                          else
                            _buildWaitingMessage(),
                          if (connectionState.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text('خطأ: ${connectionState.error}',
                                style: GoogleFonts.notoSansArabic(
                                  color: Colors.redAccent, fontSize: 13)),
                            ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
          ],
        ),
      ),
    );
  }

  Widget _glow(Color c, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: c, blurRadius: 120, spreadRadius: 40)]),
  );

  Widget _buildHeader(ConnectionState state) {
    return Container(
      color: _surface.withValues(alpha: 0.9),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: _onSurfaceVariant),
                  onPressed: () {
                    ref.read(connectionProvider.notifier).disconnect();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 4),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 7, height: 7,
                      decoration: const BoxDecoration(
                        color: _primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('الجهاز مؤمن',
                      style: GoogleFonts.notoSansArabic(
                        color: _primary, fontSize: 10, fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                  ]),
                  Text('غرفة المهمة',
                    style: GoogleFonts.spaceGrotesk(
                      color: _onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ]),
              Row(children: [
                const Icon(Icons.security, color: _primary, size: 18),
                const SizedBox(width: 6),
                Text('الأسماء الرمزية',
                  style: GoogleFonts.spaceGrotesk(
                    color: _primaryContainer, fontWeight: FontWeight.bold,
                    fontSize: 14, letterSpacing: 1)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIPCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: const Border(right: BorderSide(color: _primary, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('عنوان IP للمضيف',
              style: GoogleFonts.notoSansArabic(
                color: _outline, fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 2)),
            Text(_hostIP ?? '---',
              textDirection: TextDirection.ltr,
              style: GoogleFonts.spaceGrotesk(
                color: _primary, fontSize: 24, fontWeight: FontWeight.bold,
                letterSpacing: 2)),
          ]),
          const Icon(Icons.copy, color: _onSurfaceVariant, size: 20),
        ],
      ),
    );
  }

  Widget _buildTeamColumn({
    required Team team, required List<Player> players, required String label,
    required Color accentColor, required Color headerColor, required Color badgeColor,
    required Color badgeBg, required IconData icon, Player? localPlayer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                color: headerColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: badgeBg, borderRadius: BorderRadius.circular(999)),
          child: Text('${players.length} / 6',
            style: GoogleFonts.notoSansArabic(
              color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 10),
        ...players.map((p) => _buildPlayerTile(p, accentColor, localPlayer)),
      ],
    );
  }

  Widget _buildPlayerTile(Player player, Color accentColor, Player? localPlayer) {
    final isLocalPlayer = player.id == localPlayer?.id;
    final isSpy = player.role == Role.spymaster;

    Widget tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLocalPlayer ? _surfaceContainerHighest : _surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: isLocalPlayer
          ? Border.all(color: _primary.withValues(alpha: 0.5), width: 1.5)
          : Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.person, color: accentColor.withValues(alpha: 0.7), size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isLocalPlayer ? '${player.name} (أنت)' : player.name,
                style: GoogleFonts.spaceGrotesk(
                  color: isLocalPlayer ? _primary : _onSurface,
                  fontSize: 11, fontWeight: FontWeight.bold)),
              Text(isSpy ? 'رئيس الشبكة' : 'عميل ميداني',
                style: GoogleFonts.notoSansArabic(
                  color: isSpy ? accentColor : _onSurfaceVariant,
                  fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ]),
          ),
          if (isSpy) Icon(Icons.verified_user, color: accentColor, size: 16),
          if (isLocalPlayer) Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4)),
            child: Text('محلي',
              style: GoogleFonts.notoSansArabic(
                color: _primary, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    // Spymaster gets gradient border
    if (isSpy) {
      tile = Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.4)]),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.person, color: accentColor.withValues(alpha: 0.7), size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(player.name,
                  style: GoogleFonts.spaceGrotesk(
                    color: _onSurface, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('رئيس الشبكة',
                  style: GoogleFonts.notoSansArabic(
                    color: accentColor, fontSize: 10,
                    fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ]),
            ),
            Icon(Icons.verified_user, color: accentColor, size: 16),
          ]),
        ),
      );
    }

    return tile;
  }

  Widget _buildSettingsCard(Player localPlayer, ConnectionState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إعدادات العميل',
          style: GoogleFonts.spaceGrotesk(
            color: _onSurface, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        // Team selector
        Text('اختر انتماء الفريق',
          style: GoogleFonts.notoSansArabic(
            color: _outline, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _teamToggle(
            label: 'أحمر', dot: _tertiaryContainer,
            active: localPlayer.team == Team.red,
            activeBg: _tertiaryContainer.withValues(alpha: 0.15),
            activeBorder: _tertiaryContainer,
            onTap: () => ref.read(connectionProvider.notifier)
              .updateLocalPlayer(Team.red, localPlayer.role),
          )),
          const SizedBox(width: 8),
          Expanded(child: _teamToggle(
            label: 'أزرق', dot: _secondary,
            active: localPlayer.team == Team.blue,
            activeBg: _secondaryContainer.withValues(alpha: 0.5),
            activeBorder: _secondary,
            onTap: () => ref.read(connectionProvider.notifier)
              .updateLocalPlayer(Team.blue, localPlayer.role),
          )),
        ]),
        const SizedBox(height: 14),
        // Role
        Text('الدور التكتيكي',
          style: GoogleFonts.notoSansArabic(
            color: _outline, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 6),
        _roleDropdown(localPlayer),
        const SizedBox(height: 14),
        // Info note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.info_outline, color: _primary, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text('يقدم رؤساء الشبكة أدلة لفرقهم. مطلوب رئيس شبكة واحد على الأقل لكل فريق للانتشار.',
                style: GoogleFonts.notoSansArabic(
                  color: _onSurfaceVariant, fontSize: 11, height: 1.5)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _teamToggle({
    required String label, required Color dot, required bool active,
    required Color activeBg, required Color activeBorder, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? activeBg : _surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? activeBorder : _outlineVariant.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 8, height: 8,
            decoration: BoxDecoration(
              color: active ? dot : _outlineVariant,
              shape: BoxShape.circle,
              boxShadow: active ? [BoxShadow(color: dot.withValues(alpha: 0.5), blurRadius: 6)] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
            style: GoogleFonts.spaceGrotesk(
              color: active ? activeBorder : _onSurfaceVariant,
              fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _roleDropdown(Player localPlayer) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        border: const Border(bottom: BorderSide(color: _outlineVariant, width: 2)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8), topRight: Radius.circular(8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Role>(
          value: localPlayer.role,
          isExpanded: true,
          dropdownColor: _surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          icon: const Icon(Icons.expand_more, color: _outlineVariant),
          style: GoogleFonts.notoSansArabic(color: _onSurface, fontSize: 14),
          items: const [
            DropdownMenuItem(value: Role.operative, child: Text('عميل ميداني')),
            DropdownMenuItem(value: Role.spymaster, child: Text('رئيس الشبكة 🔍')),
          ],
          onChanged: (Role? r) {
            if (r != null) {
              ref.read(connectionProvider.notifier).updateLocalPlayer(localPlayer.team, r);
            }
          },
        ),
      ),
    );
  }

  Widget _buildLaunchSection(ConnectionState state, bool hasEnough, bool hasRedSpy, bool hasBluespy) {
    return Column(children: [
      // Launch button
      GestureDetector(
        onTap: () => _handleStartGame(state),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _primaryContainer],
              begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [BoxShadow(
              color: _primary.withValues(alpha: 0.3),
              blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.rocket_launch, color: _onPrimaryContainer, size: 20),
            const SizedBox(width: 10),
            Text('بدء المهمة',
              style: GoogleFonts.spaceGrotesk(
                color: _onPrimaryContainer, fontWeight: FontWeight.w900,
                fontSize: 16, letterSpacing: 2)),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      // Readiness checklist
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceContainerLowest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outlineVariant.withValues(alpha: 0.12))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('جاهزية الانتشار',
            style: GoogleFonts.notoSansArabic(
              color: _outline, fontSize: 10, fontWeight: FontWeight.w900,
              letterSpacing: 2)),
          const SizedBox(height: 10),
          _checkItem('الحد الأدنى من العملاء (${state.players.length}/4)', hasEnough),
          _checkItem('تم تعيين رئيس شبكة للفريق الأحمر', hasRedSpy),
          _checkItem('تم تعيين رئيس شبكة للفريق الأزرق', hasBluespy),
        ]),
      ),
    ]);
  }

  Widget _checkItem(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? Colors.green : _outlineVariant, size: 16),
        const SizedBox(width: 8),
        Text(label,
          style: GoogleFonts.notoSansArabic(
            color: _onSurfaceVariant, fontSize: 12)),
      ]),
    );
  }

  Widget _buildWaitingMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text('بانتظار المضيف لبدء اللعبة...',
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSansArabic(
          color: _onSurfaceVariant, fontSize: 15)),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceContainerLow.withValues(alpha: 0.95),
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
              _navItem(Icons.login, 'الإنضمام', false),
              _navItem(Icons.groups, 'الفريق', true),
              _navItem(Icons.grid_view, 'المهمة', false),
              _navItem(Icons.terminal, 'LOGS', false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: active ? BoxDecoration(
        color: _surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12)) : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: active ? _primary : _outlineVariant, size: 22),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.spaceGrotesk(
          color: active ? _primary : _outlineVariant.withValues(alpha: 0.7),
          fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}