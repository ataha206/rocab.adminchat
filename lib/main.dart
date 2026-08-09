import 'package:flutter/material.dart';

import 'core/push.dart';
import 'core/session.dart';
import 'screens/conversations_screen.dart';
import 'screens/login_screen.dart';
import 'splash/rocab_splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load();
  // Registers this device for support notifications (no-op until login).
  await Push.init();
  runApp(const AdminChatApp());
}

class AdminChatApp extends StatelessWidget {
  const AdminChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Support',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF128C7E),
          primary: const Color(0xFF075E54),
          secondary: const Color(0xFF25D366),
        ),
        useMaterial3: true,
        fontFamily: 'ExpoArabic',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF075E54),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF25D366),
          foregroundColor: Colors.white,
        ),
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const _SplashGate(),
    );
  }
}

/// Plays the Rocab brand intro (same animation as the rider app), then routes
/// to login or the conversations list.
class _SplashGate extends StatelessWidget {
  const _SplashGate();

  @override
  Widget build(BuildContext context) {
    return RocabSplashVisual(
      onAnimationCompleted: () {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => Session.isLoggedIn
              ? const ConversationsScreen()
              : const LoginScreen(),
        ));
      },
    );
  }
}
