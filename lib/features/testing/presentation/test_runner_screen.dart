import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/test_result.dart';
import '../suites/engine_tests.dart';
import '../suites/network_tests.dart';
import '../suites/validator_tests.dart';
import '../suites/storage_tests.dart';
import '../suites/edge_case_tests.dart';
import '../suites/state_tests.dart';
import '../suites/appwrite_tests.dart';
import '../suites/startup_tests.dart';

// ─── Design System Colors ─────────────────────────────────────────────────────
const _surface = Color(0xFF001429);
const _surfaceContainerLow = Color(0xFF001D36);
const _surfaceContainerHigh = Color(0xFF092B4A);
const _surfaceContainerHighest = Color(0xFF183655);
const _primary = Color(0xFFFFB77A);
const _primaryContainer = Color(0xFFF28E26);
const _secondary = Color(0xFF95CEEF);
const _outline = Color(0xFFA38D7C);
const _outlineVariant = Color(0xFF554336);
const _onSurface = Color(0xFFD1E4FF);
const _onSurfaceVariant = Color(0xFFDBC2B0);
const _onPrimaryContainer = Color(0xFF5D3100);
const _error = Color(0xFFFFB4AB);
const _errorContainer = Color(0xFF93000A);

// Map test names to display-friendly labels (Arabic / spy-themed)
const _testDisplayNames = <String, String>{
  'Engine: Board Generation':    'SYSTEM_ENGINE_CORE / BOARD_GEN',
  'Engine: Card Revealing':      'SYSTEM_ENGINE_CORE / CARD_REVEAL',
  'Engine: Turn Switching':      'SYSTEM_ENGINE_CORE / TURN_SWITCH',
  'Engine: N+1 Rule':            'SYSTEM_ENGINE_CORE / N_PLUS_ONE_RULE',
  'Engine: Win/Loss Conditions': 'SYSTEM_ENGINE_CORE / WIN_CONDITION',
  'Engine: Reset Game':          'SYSTEM_ENGINE_CORE / RESET',
  'Network: Host Lifecycle':     'P2P_NETWORK / HOST_LIFECYCLE',
  'Network: Client Lifecycle':   'P2P_NETWORK / CLIENT_LIFECYCLE',
  'Network: Serialization':      'P2P_NETWORK / SERIALIZATION',
  'Validators: IP Validator':    'VALIDATORS / IP_VERIFY',
  'Validators: Name Validator':  'VALIDATORS / NAME_VERIFY',
  'Storage: Hive Save/Load':     'STORAGE / INDEX_RECOVERY',
  'Storage: Error Recovery':     'STORAGE / ERROR_RECOVERY',
  'State: Connection transitions':'STATE_MACHINE / CONN_TRANSITION',
  'State: Game state updates':   'STATE_MACHINE / STATE_SYNC',
  'Edge Cases: Rapid Clicking':  'EDGE_CASES_VOL4 / BYZANTINE_FLOOD',
  'Edge Cases: Rogue Client':    'EDGE_CASES_VOL4 / ROGUE_CLIENT',
  'Appwrite: Client Initialization': 'GLOBAL_NETWORK / CLIENT_INIT',
  'Appwrite: Room Service Injection':'GLOBAL_NETWORK / SERVICE_INJECT',
  'Startup: Hive initialization':    'STARTUP_CHECKS / HIVE_INIT',
  'Startup: Network IP fetching':    'STARTUP_CHECKS / NETWORK_INTF',
  'Startup: Appwrite Anonymous Session': 'STARTUP_CHECKS / APPWRITE_SESS',
};

// Map internal test names to suite groups for section headers
const _suiteGroups = <String, String>{
  'Engine: Board Generation':    'SYSTEM_ENGINE_CORE',
  'Engine: Card Revealing':      'SYSTEM_ENGINE_CORE',
  'Engine: Turn Switching':      'SYSTEM_ENGINE_CORE',
  'Engine: N+1 Rule':            'SYSTEM_ENGINE_CORE',
  'Engine: Win/Loss Conditions': 'SYSTEM_ENGINE_CORE',
  'Engine: Reset Game':          'SYSTEM_ENGINE_CORE',
  'Network: Host Lifecycle':     'P2P_NETWORK',
  'Network: Client Lifecycle':   'P2P_NETWORK',
  'Network: Serialization':      'P2P_NETWORK',
  'Validators: IP Validator':    'VALIDATORS',
  'Validators: Name Validator':  'VALIDATORS',
  'Storage: Hive Save/Load':     'STORAGE',
  'Storage: Error Recovery':     'STORAGE',
  'State: Connection transitions':'STATE_MACHINE',
  'State: Game state updates':   'STATE_MACHINE',
  'Edge Cases: Rapid Clicking':  'EDGE_CASES_VOL4',
  'Edge Cases: Rogue Client':    'EDGE_CASES_VOL4',
  'Appwrite: Client Initialization': 'GLOBAL_NETWORK',
  'Appwrite: Room Service Injection': 'GLOBAL_NETWORK',
  'Startup: Hive initialization':    'STARTUP_CHECKS',
  'Startup: Network IP fetching':    'STARTUP_CHECKS',
  'Startup: Appwrite Anonymous Session': 'STARTUP_CHECKS',
};

class TestRunnerScreen extends ConsumerStatefulWidget {
  const TestRunnerScreen({super.key});

  @override
  ConsumerState<TestRunnerScreen> createState() => _TestRunnerScreenState();
}

class _TestRunnerScreenState extends ConsumerState<TestRunnerScreen> {
  bool _isRunning = false;
  List<TestResult> _results = [];

  @override
  void initState() {
    super.initState();
    _initializeTests();
  }

  void _initializeTests() {
    setState(() {
      _results = [
        TestResult(name: 'Engine: Board Generation'),
        TestResult(name: 'Engine: Card Revealing'),
        TestResult(name: 'Engine: Turn Switching'),
        TestResult(name: 'Engine: N+1 Rule'),
        TestResult(name: 'Engine: Win/Loss Conditions'),
        TestResult(name: 'Engine: Reset Game'),
        TestResult(name: 'Network: Host Lifecycle'),
        TestResult(name: 'Network: Client Lifecycle'),
        TestResult(name: 'Network: Serialization'),
        TestResult(name: 'Validators: IP Validator'),
        TestResult(name: 'Validators: Name Validator'),
        TestResult(name: 'Storage: Hive Save/Load'),
        TestResult(name: 'Storage: Error Recovery'),
        TestResult(name: 'State: Connection transitions'),
        TestResult(name: 'State: Game state updates'),
        TestResult(name: 'Edge Cases: Rapid Clicking'),
        TestResult(name: 'Edge Cases: Rogue Client'),
        TestResult(name: 'Appwrite: Client Initialization'),
        TestResult(name: 'Appwrite: Room Service Injection'),
        TestResult(name: 'Startup: Hive initialization'),
        TestResult(name: 'Startup: Network IP fetching'),
        TestResult(name: 'Startup: Appwrite Anonymous Session'),
      ];
    });
  }

  Future<void> _updateResult(String name, TestStatus status, {String? error, Duration? duration}) async {
    setState(() {
      final index = _results.indexWhere((r) => r.name == name);
      if (index != -1) {
        _results[index] = _results[index].copyWith(
          status: status, errorMessage: error, duration: duration);
      }
    });
  }

  Future<void> _runAllTests() async {
    if (_isRunning) return;
    setState(() { _isRunning = true; _initializeTests(); });

    final suites = [
      () => EngineTests.run(),
      () => NetworkTests.run(),
      () => ValidatorTests.run(),
      () => StorageTests.run(),
      () => StateTests.run(),
      () => EdgeCaseTests.run(),
      () => AppwriteTests.run(),
      () => StartupTests.run(),
    ];

    for (var suiteFn in suites) {
      try {
        final results = await suiteFn();
        for (var res in results) {
          await _updateResult(res.name, res.status, error: res.errorMessage, duration: res.duration);
        }
      } catch (e) { debugPrint('Suite failed: $e'); }
    }

    setState(() { _isRunning = false; });
  }

  @override
  Widget build(BuildContext context) {
    final passed = _results.where((r) => r.status == TestStatus.passed).length;
    final failed = _results.where((r) => r.status == TestStatus.failed).length;
    final stable = passed;
    final critical = failed;
    final total = _results.length;

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildHeader(total, stable, critical),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildGroupedList(),
              ),
            ),
          ),
          _buildLaunchButton(),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int stable, int critical) {
    return Container(
      color: _surfaceContainerLow,
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
                      onPressed: () => Navigator.pop(context),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('DIAGNOSTIC',
                        style: GoogleFonts.spaceGrotesk(
                          color: _primary, fontSize: 18, fontWeight: FontWeight.w900,
                          letterSpacing: 3)),
                      Text('SYSTEM INTEGRITY SCAN',
                        style: GoogleFonts.spaceGrotesk(
                          color: _outline, fontSize: 10, letterSpacing: 2)),
                    ]),
                  ]),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _primaryContainer.withValues(alpha: 0.3))),
                      child: Row(children: [
                        const Icon(Icons.favorite, color: _primaryContainer, size: 14),
                        const SizedBox(width: 6),
                        Text('SUPPORT US',
                          style: GoogleFonts.spaceGrotesk(
                            color: _primaryContainer, fontWeight: FontWeight.bold, fontSize: 11)),
                      ]),
                    ),
                  ]),
                ],
              ),
            ),
            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                _statCard('TOTAL_REPORTS', total.toString(), _onSurface),
                const SizedBox(width: 10),
                _statCard('STABLE_STATE', stable.toString(),
                  stable > 0 ? Colors.green : _onSurfaceVariant),
                const SizedBox(width: 10),
                _statCard('CRITICAL_FAIL', critical.toString(),
                  critical > 0 ? _error : _onSurfaceVariant),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(label,
            style: GoogleFonts.spaceGrotesk(
              color: _outline, fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value,
            style: GoogleFonts.spaceGrotesk(
              color: valueColor, fontSize: 28, fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }

  Widget _buildGroupedList() {
    // Group results by suite
    final groups = <String, List<TestResult>>{};
    for (final r in _results) {
      final group = _suiteGroups[r.name] ?? 'OTHER';
      groups.putIfAbsent(group, () => []).add(r);
    }

    final suiteDotColors = <String, Color>{
      'SYSTEM_ENGINE_CORE': _error,
      'P2P_NETWORK': _primary,
      'VALIDATORS': _outlineVariant,
      'STORAGE': const Color(0xFF6FAF8D),
      'STATE_MACHINE': _onSurface,
      'EDGE_CASES_VOL4': _primaryContainer,
      'GLOBAL_NETWORK': _secondary,
      'STARTUP_CHECKS': Colors.purpleAccent,
    };

    return Column(
      children: [
        const SizedBox(height: 12),
        ...groups.entries.map((e) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(e.key, suiteDotColors[e.key] ?? _outline),
            ...e.value.map((r) => _testTile(r)),
          ],
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionHeader(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(title,
          style: GoogleFonts.spaceGrotesk(
            color: accent, fontSize: 11, fontWeight: FontWeight.w900,
            letterSpacing: 2)),
      ]),
    );
  }

  Widget _testTile(TestResult r) {
    final label = _testDisplayNames[r.name] ?? r.name;
    final prefix = label.contains('/') ? label.split('/').last.trim() : label;
    final sub = _subText(r);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _statusBorderColor(r.status).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prefix,
                style: GoogleFonts.spaceGrotesk(
                  color: _statusTextColor(r.status),
                  fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub,
                  style: GoogleFonts.spaceGrotesk(
                    color: r.status == TestStatus.failed ? _error : _outline,
                    fontSize: 10)),
              ],
            ]),
          ),
          _statusWidget(r),
        ],
      ),
    );
  }

  String? _subText(TestResult r) {
    switch (r.status) {
      case TestStatus.pending: return 'AWAITING SIGNAL';
      case TestStatus.running: return 'SCANNING...';
      case TestStatus.passed:
        return 'OK — ${r.duration?.inMilliseconds ?? 0}ms';
      case TestStatus.failed:
        return r.errorMessage ?? 'CRITICAL FAILURE';
    }
  }

  Widget _statusWidget(TestResult r) {
    switch (r.status) {
      case TestStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6)),
          child: Text('PENDING',
            style: GoogleFonts.spaceGrotesk(
              color: _outline, fontSize: 9, fontWeight: FontWeight.bold)));
      case TestStatus.running:
        return const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(color: _primary, strokeWidth: 2));
      case TestStatus.passed:
        return const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);
      case TestStatus.failed:
        return const Icon(Icons.cancel_rounded, color: _error, size: 20);
    }
  }

  Color _statusBorderColor(TestStatus s) {
    return switch (s) {
      TestStatus.passed => Colors.green,
      TestStatus.failed => _errorContainer,
      TestStatus.running => _primary,
      TestStatus.pending => _outlineVariant,
    };
  }

  Color _statusTextColor(TestStatus s) {
    return switch (s) {
      TestStatus.passed => Colors.green,
      TestStatus.failed => _error,
      TestStatus.running => _primary,
      TestStatus.pending => _onSurfaceVariant,
    };
  }

  Widget _buildLaunchButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        border: Border(top: BorderSide(color: _outlineVariant.withValues(alpha: 0.2)))),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _isRunning ? null : _runAllTests,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: _isRunning
                ? const LinearGradient(colors: [_surfaceContainerHigh, _surfaceContainerHighest])
                : const LinearGradient(colors: [_primary, _primaryContainer]),
              borderRadius: BorderRadius.circular(999),
              boxShadow: _isRunning ? null : [BoxShadow(
                color: _primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_isRunning) ...[
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: _onPrimaryContainer, strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('SCANNING SYSTEMS...',
                  style: GoogleFonts.spaceGrotesk(
                    color: _outline, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2)),
              ] else ...[
                const Icon(Icons.play_arrow_rounded, color: _onPrimaryContainer, size: 20),
                const SizedBox(width: 8),
                Text('RUN ALL TESTS',
                  style: GoogleFonts.spaceGrotesk(
                    color: _onPrimaryContainer, fontWeight: FontWeight.w900,
                    fontSize: 13, letterSpacing: 2.5)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
