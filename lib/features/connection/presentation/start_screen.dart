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
    if (lastIP != null) {
      _ipController.text = lastIP;
    }
    final lastName = _settingsBox.get('lastName');
    if (lastName != null) {
      _nameController.text = lastName;
    }
  }

  void _saveData(String? ip, String name) {
    if (ip != null) _settingsBox.put('lastIP', ip);
    _settingsBox.put('lastName', name);
  }

  Future<void> _fetchLocalIP() async {
    final ip = await IPUtils.getIPAddress();
    if (mounted) {
      setState(() {
        _localIp = ip;
      });
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسمك أولاً')),
      );
      return;
    }

    if (_localIp != null) {
      _logger.i('Hosting game with IP: $_localIp');
      _saveData(null, name);
      ref.read(connectionProvider.notifier).startHosting(name);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LobbyScreen()),
      );
    } else {
      _logger.e('Failed to get IP address for hosting');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في جلب عنوان IP المحلي')),
      );
    }
  }

  void _handleJoinGame() {
    final ip = _ipController.text.trim();
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسمك أولاً')),
      );
      return;
    }

    final validationError = Validators.validateIPAddress(ip);
    if (validationError != null) {
      _logger.w('Join game failed: $validationError');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }
    
    _logger.i('Joining game with IP: $ip');
    ref.read(connectionProvider.notifier).joinGame(ip, name);
    _saveData(ip, name);
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
          'الأسماء السرية P2P',
          style: TextStyle(fontSize: 20.sp),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'مرحباً بك في الأسماء السرية!',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'أدخل اسمك',
                  hintText: 'مثال: أحمد',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() {}),
              ),
              SizedBox(height: 24.h),
              if (_localIp != null) ...[
                Text(
                  'عنوان الـ IP الخاص بك: $_localIp',
                  style: TextStyle(fontSize: 16.sp, color: Colors.blueGrey),
                ),
                SizedBox(height: 8.h),
              ],
              ElevatedButton(
                onPressed: _handleHostGame,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50.h),
                  textStyle: TextStyle(fontSize: 18.sp),
                ),
                child: const Text('إنشاء غرفة (مضيف)'),
              ),
              SizedBox(height: 32.h),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'أدخل عنوان الـ IP للاتصال',
                  hintText: 'مثال: 192.168.1.100',
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
                child: const Text('انضمام للعبة'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TestRunnerScreen()),
          );
        },
        label: const Text('اختبار ذاتي 🧪'),
        icon: const Icon(Icons.science),
        backgroundColor: Colors.purple.shade200,
      ),
    );
  }
}