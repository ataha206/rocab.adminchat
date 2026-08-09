import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api.dart';
import 'session.dart';

/// FCM registration for the support-staff device: asks permission, sends the
/// token to the backend after login, and re-sends it whenever FCM rotates it.
/// Background/killed-state notifications are shown by the OS automatically
/// (the backend sends notification-type messages).
class Push {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.instance.onTokenRefresh.listen(_register);
      await registerIfLoggedIn();
    } catch (_) {
      // Missing google-services config must never break the app.
    }
  }

  static Future<void> registerIfLoggedIn() async {
    if (!Session.isLoggedIn) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
    } catch (_) {}
  }

  static Future<void> _register(String token) async {
    if (!Session.isLoggedIn) return;
    try {
      await Api.registerDevice(token);
    } catch (_) {}
  }
}
