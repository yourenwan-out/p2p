import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'features/connection/presentation/start_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Disable Logger in release/profile to prevent ANR ──
  Logger.level = kReleaseMode ? Level.off : Level.warning;

  try {
    // Wrap Hive init with timeout in case emulator storage is locked
    await Future.microtask(() async {
      await Hive.initFlutter();
      await Hive.openBox('settingsBox');
    }).timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('Hive init timeout/error (Safe Boot): $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone X size as base
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'الأسماء السرية',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: const Color(0xFF001429),
          ),
          builder: (context, childWidget) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: childWidget!,
            );
          },
          home: const StartScreen(),
        );
      },
    );
  }
}