import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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
      // iOS mints the FCM token only after the APNs token is available, which
      // can lag a second or two after launch. Getting the FCM token too early
      // returns null and the device silently never registers — so wait for the
      // APNs token first (up to ~8s) before asking for the FCM token.
      if (Platform.isIOS) {
        var apns = await FirebaseMessaging.instance.getAPNSToken();
        for (var i = 0; apns == null && i < 8; i++) {
          await Future.delayed(const Duration(seconds: 1));
          apns = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apns == null && kDebugMode) {
          debugPrint('Push: APNs token still null — check the APNs key in '
              'the Firebase project and Push Notifications capability.');
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _register(token);
      } else if (kDebugMode) {
        debugPrint('Push: FCM getToken() returned null — device not registered.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Push.registerIfLoggedIn failed: $e');
    }
  }

  static Future<void> _register(String token) async {
    if (!Session.isLoggedIn) return;
    try {
      await Api.registerDevice(token);
    } catch (e) {
      if (kDebugMode) debugPrint('Push.registerDevice failed: $e');
    }
  }
}
