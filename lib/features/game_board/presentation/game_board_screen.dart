import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:p2p_codenames/core/network/connection_provider.dart';
import 'package:p2p_codenames/features/game_board/providers/game_provider.dart';
import 'package:p2p_codenames/features/game_board/models/game_state.dart';
import 'package:p2p_codenames/features/game_board/models/word_card.dart';
import 'package:p2p_codenames/features/game_board/models/player.dart';

// ─── Design System Colors ─────────────────────────────────────────────────────
const _surface = Color(0xFF001429);
const _surfaceContainerLow = Color(0xFF001D36);
const _surfaceContainerHigh = Color(0xFF092B4A);
const _surfaceContainerHighest = Color(0xFF183655);
const _surfaceContainerLowest = Color(0xFF000F20);
const _surfaceContainer = Color(0xFF00213D);
const _surfaceVariant = Color(0xFF183655);
const _surfaceBright = Color(0xFF1D3B5A);
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
const _error = Color(0xFFFFB4AB);

class GameBoardScreen extends ConsumerStatefulWidget {
  const GameBoardScreen({super.key});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  final TextEditingController _clueWordCtrl = TextEditingController();
  int _clueNumber = 1;

  @override
  void dispose() {
    _clueWordCtrl.dispose();
    super.dispose();
  }

  void _sendClue() {
    final word = _clueWordCtrl.text.trim();
    if (word.isEmpty || word.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('الرجاء إدخال كلمة واحدة فقط بدون مسافات',
          style: GoogleFonts.notoSansArabic()),
        backgroundColor: _surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    ref.read(connectionProvider.notifier).sendClue(word, _clueNumber);
    _clueWordCtrl.clear();
    setState(() => _clueNumber = 1);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final connectionState = ref.watch(connectionProvider);
    final notifier = ref.read(connectionProvider.notifier);

    Player? localPlayer;
    if (connectionState.localPlayerId != null) {
      try {
        localPlayer = connectionState.players
            .firstWhere((p) => p.id == connectionState.localPlayerId);
      } catch (_) {}
    }

    final isSpymaster = localPlayer?.role == Role.spymaster;
    final redLeft = 9 - gameState.cards.where((c) => c.color == CardColor.red && c.isRevealed).length;
    final blueLeft = 8 - gameState.cards.where((c) => c.color == CardColor.blue && c.isRevealed).length;

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
            // Ambient background glows
            Positioned(top: 0, right: -60,
              child: _glow(_primary.withValues(alpha: 0.04), 280)),
            Positioned(bottom: 100, left: -60,
              child: _glow(_secondary.withValues(alpha: 0.03), 260)),

            Column(
              children: [
                _buildHeader(localPlayer, gameState, redLeft, blueLeft),
                if (!gameState.isGameOver)
                  _buildControlZone(localPlayer, gameState, notifier),
                if (isSpymaster)
                  _buildSpymasterBoard(gameState, localPlayer)
                else
                  _buildOperativeBoard(gameState, localPlayer, notifier),
                if (gameState.isGameOver)
                  _buildGameOverBanner(gameState, connectionState),
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

  // ─── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader(Player? localPlayer, GameState gameState, int redLeft, int blueLeft) {
    final teamName = localPlayer?.team == Team.red ? 'الفريق الأحمر' : 'الفريق الأزرق';
    return Container(
      color: _surfaceContainer.withValues(alpha: 0.97),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: _onSurfaceVariant, size: 20),
                      onPressed: () {
                        ref.read(connectionProvider.notifier).disconnect();
                        Navigator.pop(context);
                      },
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.security, color: _primaryContainer, size: 16),
                        const SizedBox(width: 6),
                        Text('الأسماء الرمزية',
                          style: GoogleFonts.spaceGrotesk(
                            color: _primaryContainer, fontWeight: FontWeight.bold,
                            fontSize: 16, letterSpacing: 1)),
                      ]),
                      Text('جلسة نشطة',
                        style: GoogleFonts.notoSansArabic(
                          color: _outline, fontSize: 10, letterSpacing: 2)),
                    ]),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _primary.withValues(alpha: 0.3))),
                    child: Row(children: [
                      const Icon(Icons.favorite, color: _primaryContainer, size: 16),
                      const SizedBox(width: 6),
                      Text('إدعمنا',
                        style: GoogleFonts.notoSansArabic(
                          color: _onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ),
                ],
              ),
            ),
            // Score row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(child: _scoreChip('الأصول الحمراء', redLeft, _tertiary, _tertiaryContainer)),
                  const SizedBox(width: 8),
                  Expanded(child: _scoreChip('الأصول الزرقاء', blueLeft, _secondary, _secondaryContainer)),
                ],
              ),
            ),
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: _surfaceContainerLowest.withValues(alpha: 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    container(7, 7, _primary, BoxShape.circle, animate: true),
                    const SizedBox(width: 6),
                    Text('الرقابة التكتيكية نشطة',
                      style: GoogleFonts.notoSansArabic(
                        color: _outline, fontSize: 9, fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                  ]),
                  Text('بث شبكي مشفر 5x5. تجنب الجهاز الأسود.',
                    style: GoogleFonts.notoSansArabic(
                      color: _onSurfaceVariant.withValues(alpha: 0.8), fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget container(double w, double h, Color c, BoxShape shape, {bool animate = false}) {
    return Container(width: w, height: h,
      decoration: BoxDecoration(color: c, shape: shape));
  }

  Widget _scoreChip(String label, int count, Color accent, Color border) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.5), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.notoSansArabic(
            color: accent, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text('$count', style: GoogleFonts.spaceGrotesk(
            color: _onSurface, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // ─── CONTROL ZONE ─────────────────────────────────────────────────────────
  Widget _buildControlZone(Player? localPlayer, GameState gameState, notifier) {
    if (localPlayer == null) return const SizedBox.shrink();

    if (localPlayer.role == Role.spymaster) {
      return _buildSpymasterControl(localPlayer, gameState);
    } else {
      return _buildOperativeControl(localPlayer, gameState, notifier);
    }
  }

  Widget _buildSpymasterControl(Player localPlayer, GameState gameState) {
    if (localPlayer.team != gameState.currentTurn) {
      return _controlBanner_waiting('بانتظار دور فريقك...', Icons.hourglass_empty);
    }
    if (gameState.currentClueWord != null) {
      return _controlBanner_waiting('لقد أعطيت تلميحاً! بانتظار العملاء...', Icons.record_voice_over, color: _secondary);
    }
    // Input panel
    return Container(
      color: _surfaceContainerLow.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.record_voice_over, color: _primary, size: 14),
              const SizedBox(width: 6),
              Text('دورك لإعطاء تلميح',
                style: GoogleFonts.notoSansArabic(
                  color: _primary, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
            if (gameState.currentClueWord != null)
              Text('آخر بث: ${gameState.currentClueWord}',
                style: GoogleFonts.notoSansArabic(
                  color: _outline, fontSize: 9)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Send button (icon only on left in RTL)
            GestureDetector(
              onTap: _sendClue,
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_primary, _primaryContainer]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 10)],
                ),
                child: const Icon(Icons.send, color: _onPrimaryContainer, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            // Number
            SizedBox(
              width: 80,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('العدد',
                  style: GoogleFonts.notoSansArabic(
                    color: _outline, fontSize: 9, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: _surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _outlineVariant.withValues(alpha: 0.3))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _clueNumber,
                      isExpanded: true,
                      dropdownColor: _surfaceContainerHigh,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      icon: const Icon(Icons.expand_more, color: _outlineVariant, size: 16),
                      style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 14),
                      items: [0,1,2,3,4,5,6,7,8,9,99].map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e == 99 ? '∞' : '$e'),
                      )).toList(),
                      onChanged: (v) => setState(() => _clueNumber = v!),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            // Word input
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('كلمة التلميح',
                  style: GoogleFonts.notoSansArabic(
                    color: _outline, fontSize: 9, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _clueWordCtrl,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.spaceGrotesk(color: _onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'أدخل كلمة واحدة...',
                      hintStyle: GoogleFonts.notoSansArabic(
                        color: _outlineVariant.withValues(alpha: 0.4), fontSize: 12),
                      filled: true,
                      fillColor: _surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _outlineVariant.withValues(alpha: 0.3))),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _outlineVariant.withValues(alpha: 0.3))),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _primary)),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _buildOperativeControl(Player localPlayer, GameState gameState, notifier) {
    if (gameState.currentClueWord == null) {
      return _controlBanner_waiting('الرئيس يفكر بالتلميح...', Icons.psychology, color: _onSurfaceVariant);
    }

    final maxGuesses = gameState.currentClueNumber == 99 ? 99 : (gameState.currentClueNumber! + 1);
    final canPass = localPlayer.team == gameState.currentTurn &&
        gameState.remainingGuesses < maxGuesses;
    final isMyTurn = localPlayer.team == gameState.currentTurn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: _surfaceContainerLow,
      child: Row(
        children: [
          // Clue display
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.terminal, color: _primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('حمولة الاستخبارات',
                style: GoogleFonts.notoSansArabic(
                  color: _outline, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(gameState.currentClueWord ?? '',
                    style: GoogleFonts.spaceGrotesk(
                      color: _primary, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 6),
                  Text('/ ${gameState.currentClueNumber == 99 ? "∞" : gameState.currentClueNumber}',
                    style: GoogleFonts.spaceGrotesk(
                      color: _primaryContainer, fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
              Text('متبقي: ${gameState.remainingGuesses == 99 ? "∞" : gameState.remainingGuesses}',
                style: GoogleFonts.notoSansArabic(
                  color: _outline, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
          if (canPass && isMyTurn)
            GestureDetector(
              onTap: () => notifier.sendPassTurn(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_primary, _primaryContainer]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 12)],
                ),
                child: Row(children: [
                  Text('إنهاء الدور',
                    style: GoogleFonts.notoSansArabic(
                      color: _onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_back_ios, color: _onPrimaryContainer, size: 12),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _controlBanner_waiting(String msg, IconData icon, {Color color = const Color(0xFF95CEEF)}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _surfaceContainerLow,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(msg, style: GoogleFonts.notoSansArabic(
          color: color, fontSize: 13, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  // ─── SPYMASTER BOARD (xray) ────────────────────────────────────────────────
  Widget _buildSpymasterBoard(GameState gameState, Player? localPlayer) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 80),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, crossAxisSpacing: 3, mainAxisSpacing: 3,
            childAspectRatio: 1.0),
          itemCount: 25,
          itemBuilder: (context, i) {
            final card = gameState.cards[i];
            return _SpymasterCard(card: card);
          },
        ),
      ),
    );
  }

  // ─── OPERATIVE BOARD ──────────────────────────────────────────────────────
  Widget _buildOperativeBoard(GameState gameState, Player? localPlayer, notifier) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 80),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, crossAxisSpacing: 6, mainAxisSpacing: 6,
            childAspectRatio: 0.82),
          itemCount: 25,
          itemBuilder: (context, i) {
            final card = gameState.cards[i];
            final canTap = _canClickCard(card, localPlayer, gameState);
            return _OperativeCard(
              card: card,
              canTap: canTap,
              onTap: canTap ? () => notifier.sendCardFlip(i) : null,
            );
          },
        ),
      ),
    );
  }

  bool _canClickCard(WordCard card, Player? localPlayer, GameState gameState) {
    if (card.isRevealed) return false;
    if (gameState.isGameOver) return false;
    if (localPlayer == null) return false;
    if (localPlayer.role != Role.operative) return false;
    if (gameState.currentTurn != localPlayer.team) return false;
    if (gameState.currentClueWord == null) return false;
    if (gameState.remainingGuesses <= 0) return false;
    return true;
  }

  // ─── GAME OVER BANNER ────────────────────────────────────────────────────
  Widget _buildGameOverBanner(GameState gameState, connectionState) {
    final isRed = gameState.winner == Team.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRed
              ? [const Color(0xFFFF835F), const Color(0xFFFFB5A0)]
              : [const Color(0xFF034F6B), const Color(0xFF95CEEF)],
          begin: Alignment.topRight, end: Alignment.bottomLeft),
      ),
      child: Column(children: [
        Text(
          'انتهت اللعبة! الفائز: ${isRed ? "الفريق الأحمر 🔴" : "الفريق الأزرق 🔵"}',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        if (connectionState.isHost) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              ref.read(gameProvider.notifier).resetGame();
              connectionState.socketHost?.broadcastGameState(ref.read(gameProvider));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5))),
              child: Text('إعادة اللعب',
                style: GoogleFonts.notoSansArabic(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ]),
    );
  }

  // ─── BOTTOM NAV ──────────────────────────────────────────────────────────
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
              _navItem(Icons.terminal, 'LOGS', false),
              _navItem(Icons.grid_view, 'المهمة', true),
              _navItem(Icons.groups, 'الفريق', false),
              _navItem(Icons.login, 'الإنضمام', false),
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

// ─── Spymaster Card Widget ────────────────────────────────────────────────────
class _SpymasterCard extends StatelessWidget {
  final WordCard card;
  const _SpymasterCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final (bg, textColor, borderColor) = _getSpymasterStyle(card);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bg, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(card.word,
              style: GoogleFonts.notoSansArabic(
                color: textColor, fontSize: 10, fontWeight: FontWeight.bold,
                decoration: card.isRevealed ? TextDecoration.lineThrough : null),
              textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  (List<Color>, Color, Color) _getSpymasterStyle(WordCard c) {
    if (c.isRevealed) {
      return switch (c.color) {
        CardColor.red => ([const Color(0xFFFF835F), const Color(0xFFFFB5A0)], Colors.white, _tertiaryContainer),
        CardColor.blue => ([const Color(0xFF034F6B), const Color(0xFF95CEEF)], Colors.white, _secondary),
        CardColor.assassin => ([Colors.black, const Color(0xFF1a1a1a)], const Color(0xFFFFB4AB), Colors.redAccent),
        CardColor.neutral => ([const Color(0xFF554336), const Color(0xFF183655)], _onSurfaceVariant, _outlineVariant),
      };
    }
    return switch (c.color) {
      CardColor.red => ([
          const Color(0xFFFF835F).withAlpha(60),
          const Color(0xFF93000A).withAlpha(120),
        ], _onSurface, const Color(0xFFFF835F).withAlpha(50)),
      CardColor.blue => ([
          const Color(0xFF034F6B).withAlpha(120),
          const Color(0xFF95CEEF).withAlpha(50),
        ], _onSurface, const Color(0xFF95CEEF).withAlpha(50)),
      CardColor.assassin => ([Colors.black, const Color(0xFF111111)], _error, Colors.redAccent.withAlpha(100)),
      CardColor.neutral => ([
          const Color(0xFF183655).withAlpha(120),
          const Color(0xFF00213D).withAlpha(180),
        ], _onSurface.withAlpha(150), const Color(0xFF183655).withAlpha(80)),
    };
  }
}

// ─── Operative Card Widget ────────────────────────────────────────────────────
class _OperativeCard extends StatelessWidget {
  final WordCard card;
  final bool canTap;
  final VoidCallback? onTap;
  const _OperativeCard({required this.card, required this.canTap, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (card.isRevealed) return _revealedCard();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: canTap
              ? Border.all(color: Colors.lightGreen.shade400, width: 1.5)
              : Border.all(color: Colors.transparent),
          boxShadow: canTap ? [BoxShadow(
            color: Colors.lightGreen.withValues(alpha: 0.15),
            blurRadius: 8)] : null,
        ),
        child: Stack(
          children: [
            if (canTap) Positioned(
              top: 6, right: 6,
              child: Icon(Icons.fingerprint,
                color: _outline.withValues(alpha: 0.3), size: 12),
            ),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(card.word,
                      style: GoogleFonts.notoSansArabic(
                        color: canTap ? _onSurface : _onSurfaceVariant,
                        fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      textAlign: TextAlign.center),
                  ),
                ),
                Container(width: 24, height: 2,
                  decoration: BoxDecoration(
                    color: canTap ? _primary.withValues(alpha: 0.5) : _outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _revealedCard() {
    final (colors, icon, textColor) = switch (card.color) {
      CardColor.red => (
        [const Color(0xFFFF835F), const Color(0xFFFFB5A0)],
        Icons.dangerous,
        const Color(0xFF3B0900),
      ),
      CardColor.blue => (
        [const Color(0xFF034F6B), const Color(0xFF95CEEF)],
        Icons.verified,
        const Color(0xFF001E2C),
      ),
      CardColor.assassin => (
        [Colors.black, const Color(0xFF1A1A1A)],
        Icons.skull,
        const Color(0xFFFFB4AB),
      ),
      CardColor.neutral => (
        <Color>[],
        Icons.block,
        _outline,
      ),
    };

    if (card.color == CardColor.neutral) {
      return Container(
        decoration: BoxDecoration(
          color: _outlineVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _outlineVariant.withValues(alpha: 0.15))),
        child: Stack(children: [
          Positioned.fill(child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: CustomPaint(painter: _DiagonalPainter()),
          )),
          Center(child: Text(card.word,
            style: GoogleFonts.notoSansArabic(
              color: _outline, fontSize: 14, fontWeight: FontWeight.bold,
              decoration: TextDecoration.lineThrough,
              decorationColor: _outline))),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.last.withValues(alpha: 0.3))),
      child: Stack(children: [
        Positioned(bottom: 6, left: 6,
          child: Icon(icon, color: textColor.withAlpha(100), size: 16)),
        Center(child: Padding(
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(card.word,
              style: GoogleFonts.notoSansArabic(
                color: textColor, fontSize: 14, fontWeight: FontWeight.bold,
                decoration: TextDecoration.lineThrough,
                decorationColor: textColor.withAlpha(150)),
              textAlign: TextAlign.center),
          ),
        )),
      ]),
    );
  }
}

class _DiagonalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (double i = -size.height; i < size.width + size.height; i += 18) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}