import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:p2p_codenames/core/network/connection_provider.dart';
import 'package:p2p_codenames/core/network/ip_utils.dart';
import 'package:p2p_codenames/core/utils/validators.dart';
import 'lobby_screen.dart';
import '../../testing/presentation/test_runner_screen.dart';

// ─── Design System Colors ────────────────────────────────────────────────────
const _surface = Color(0xFF001429);
const _surfaceContainerLow = Color(0xFF001D36);
const _surfaceContainerHighest = Color(0xFF183655);
// _surfaceContainerHigh reserved for future use
const _primary = Color(0xFFFFB77A);
const _primaryContainer = Color(0xFFF28E26);
const _secondary = Color(0xFF95CEEF);
const _secondaryContainer = Color(0xFF034F6B);
const _outline = Color(0xFFA38D7C);
const _outlineVariant = Color(0xFF554336);
const _onSurface = Color(0xFFD1E4FF);
const _onSurfaceVariant = Color(0xFFDBC2B0);
const _onPrimaryContainer = Color(0xFF5D3100);

class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final Logger _logger = Logger();
  late Box _settingsBox;
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settingsBox');
    _loadValues();
    _fetchLocalIP();
  }

  void _loadValues() {
    final lastIP = _settingsBox.get('lastIP');
    if (lastIP != null) _ipController.text = lastIP;
    final lastName = _settingsBox.get('lastName');
    if (lastName != null) _nameController.text = lastName;
  }

  void _saveData(String? ip, String name) {
    if (ip != null) _settingsBox.put('lastIP', ip);
    _settingsBox.put('lastName', name);
  }

  Future<void> _fetchLocalIP() async {
    final ip = await IPUtils.getIPAddress();
    if (mounted) setState(() => _localIp = ip);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleHostGame() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('الرجاء إدخال اسمك الرمزي أولاً');
      return;
    }
    if (_localIp != null) {
      _logger.i('Hosting game with IP: $_localIp');
      _saveData(null, name);
      ref.read(connectionProvider.notifier).startHosting(name);
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
    } else {
      _showSnack('فشل في جلب عنوان IP المحلي');
    }
  }

  void _handleJoinGame() {
    final ip = _ipController.text.trim();
    final name = _nameController.text.trim();
    if (name.isEmpty) { _showSnack('الرجاء إدخال اسمك الرمزي أولاً'); return; }
    final validationError = Validators.validateIPAddress(ip);
    if (validationError != null) { _showSnack(validationError); return; }
    _logger.i('Joining game with IP: $ip');
    ref.read(connectionProvider.notifier).joinGame(ip, name);
    _saveData(ip, name);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
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
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // Ambient glow decoration
          Positioned(top: MediaQuery.of(context).size.height * 0.1, right: -60,
            child: _glowBlob(_primary.withValues(alpha: 0.08), 300)),
          Positioned(bottom: MediaQuery.of(context).size.height * 0.1, left: -60,
            child: _glowBlob(_secondary.withValues(alpha: 0.04), 350)),
          // Mesh grid
          Positioned.fill(child: _MeshGrid()),
          // Scrollable content
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 100),
                        _buildHeroSection(),
                        const SizedBox(height: 40),
                        _buildNameInput(),
                        const SizedBox(height: 64),
                        _buildHostCard(),
                        const SizedBox(height: 20),
                        _buildJoinCard(),
                        const SizedBox(height: 48),
                        _buildSelfTestButton(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Bottom Nav
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
              _pillButton(icon: Icons.favorite, label: 'إدعمنا', onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: _secondaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _secondary.withValues(alpha: 0.3)),
          ),
          child: Text('الحالة التشغيلية: الاستعداد',
            style: GoogleFonts.notoSansArabic(
              color: _secondary, fontSize: 11, fontWeight: FontWeight.w600,
              letterSpacing: 2)),
        ),
        const SizedBox(height: 28),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(children: [
            TextSpan(text: 'حدد هويتك،\n',
              style: GoogleFonts.spaceGrotesk(
                color: _onSurface, fontSize: 44, fontWeight: FontWeight.bold,
                height: 1.2)),
            TextSpan(text: 'أيها العميل',
              style: GoogleFonts.spaceGrotesk(
                color: _primary, fontSize: 44, fontWeight: FontWeight.bold,
                height: 1.3)),
            TextSpan(text: '.',
              style: GoogleFonts.spaceGrotesk(
                color: _onSurface, fontSize: 44, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 16),
        Text('قم بتأمين اتصالك بشبكة الاستخبارات العالمية.\nالأسماء الرمزية إلزامية لجميع العمليات الميدانية.',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansArabic(
            color: _onSurfaceVariant.withValues(alpha: 0.8), fontSize: 15, height: 1.7)),
      ],
    );
  }

  Widget _buildNameInput() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: _surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24)],
      ),
      child: Column(
        children: [
          Text('تعريف العميل',
            style: GoogleFonts.notoSansArabic(
              color: _outline, fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 3)),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Center(
                  child: Icon(Icons.fingerprint,
                    color: _primary.withValues(alpha: 0.12), size: 60),
                ),
              ),
              TextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: _onSurface, fontSize: 24, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'أدخل الاسم الرمزي..',
                  hintStyle: GoogleFonts.spaceGrotesk(
                    color: _outline.withValues(alpha: 0.3), fontSize: 22),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: _outline.withValues(alpha: 0.25), width: 2.5)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _outline.withValues(alpha: 0.25), width: 2.5)),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: _primary, width: 2.5)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHostCard() {
    return _ActionCard(
      tag: 'تهيئة الجهاز',
      title: 'إنشاء مهمة',
      subtitle: 'استضف خادمًا آمنًا ونسق عمليات الفريق كمحلل رئيسي.',
      buttonLabel: 'تشغيل الخادم',
      buttonIcon: Icons.rocket_launch,
      accentColor: _primary,
      gradientStart: _primary,
      gradientEnd: _primaryContainer,
      circleIcon: Icons.hub,
      onTap: _handleHostGame,
      bgColor: _surfaceContainerLow,
    );
  }

  Widget _buildJoinCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('اتصال خارجي',
                  style: GoogleFonts.notoSansArabic(
                    color: _secondary, fontSize: 11, fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
                const SizedBox(height: 6),
                Text('انضمام لمهمة',
                  style: GoogleFonts.spaceGrotesk(
                    color: _onSurface, fontSize: 30, fontWeight: FontWeight.bold)),
              ]),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _secondary.withValues(alpha: 0.12)),
                child: const Icon(Icons.login, color: _secondary, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(children: [
            Text('عنوان IP المستهدف',
              style: GoogleFonts.notoSansArabic(
                color: _outline.withValues(alpha: 0.7), fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 2)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.spaceGrotesk(
                      color: _onSurface, fontSize: 20, letterSpacing: 3),
                    decoration: InputDecoration(
                      hintText: '192.168.1.1',
                      hintStyle: GoogleFonts.spaceGrotesk(
                        color: _outline.withValues(alpha: 0.25), fontSize: 18),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: _outline.withValues(alpha: 0.25), width: 2)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: _outline.withValues(alpha: 0.25), width: 2)),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: _secondary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _handleJoinGame,
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: _secondary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: _secondary.withValues(alpha: 0.3), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.chevron_left, color: Color(0xFF003549), size: 28),
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSelfTestButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const TestRunnerScreen())),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 6, height: 6,
            decoration: const BoxDecoration(color: _outlineVariant, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Text('الاختبار الذاتي',
            style: GoogleFonts.notoSansArabic(
              color: _outlineVariant, fontWeight: FontWeight.w700,
              fontSize: 11, letterSpacing: 4,
              decoration: TextDecoration.underline,
              decorationColor: _outlineVariant.withValues(alpha: 0.3))),
          const SizedBox(width: 16),
          Container(width: 6, height: 6,
            decoration: const BoxDecoration(color: _outlineVariant, shape: BoxShape.circle)),
        ],
      ),
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
              _navItem(icon: Icons.login, label: 'الإنضمام', active: true),
              _navItem(icon: Icons.groups, label: 'الفريق', active: false),
              _navItem(icon: Icons.grid_view, label: 'المهمة', active: false),
              _navItem(icon: Icons.terminal, label: 'LOGS', active: false),
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
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.spaceGrotesk(
          color: active ? _primary : _outlineVariant.withValues(alpha: 0.7),
          fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ]),
    );
  }
}

// ─── Action Card Widget (Host) ────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String tag, title, subtitle, buttonLabel;
  final IconData buttonIcon, circleIcon;
  final Color accentColor, gradientStart, gradientEnd, bgColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.tag, required this.title, required this.subtitle,
    required this.buttonLabel, required this.buttonIcon, required this.circleIcon,
    required this.accentColor, required this.gradientStart, required this.gradientEnd,
    required this.bgColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.07)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24)],
      ),
      child: Stack(
        children: [
          // Background glow
          Positioned(top: -40, left: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tag,
                        style: GoogleFonts.notoSansArabic(
                          color: accentColor, fontSize: 11, fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(title,
                        style: GoogleFonts.spaceGrotesk(
                          color: _onSurface, fontSize: 30, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(alpha: 0.12),
                      border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                    ),
                    child: Icon(circleIcon, color: accentColor, size: 32),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(subtitle,
                style: GoogleFonts.notoSansArabic(
                  color: _onSurfaceVariant, fontSize: 14, height: 1.6)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [gradientStart, gradientEnd],
                      begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(
                      color: gradientStart.withValues(alpha: 0.3),
                      blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(buttonLabel,
                      style: GoogleFonts.notoSansArabic(
                        color: _onPrimaryContainer, fontWeight: FontWeight.bold,
                        fontSize: 14, letterSpacing: 1)),
                    const SizedBox(width: 10),
                    Icon(buttonIcon, color: _onPrimaryContainer, size: 18),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Mesh Grid Background ─────────────────────────────────────────────────────
class _MeshGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MeshPainter());
  }
}

class _MeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF183655).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}