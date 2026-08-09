import 'package:shared_preferences/shared_preferences.dart';

/// Auth token + server URL, persisted across restarts.
class Session {
  static const _kToken = 'token';
  static const _kUserName = 'user_name';
  static const _kServer = 'server_url';

  static String apiBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://daapi.arttech.ps',
  );
  static String? token;
  static String? userName;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_kToken);
    userName = p.getString(_kUserName);
    final server = p.getString(_kServer);
    if (server != null && server.isNotEmpty) apiBaseUrl = server;
  }

  static Future<void> save(String newToken, String newUserName) async {
    token = newToken;
    userName = newUserName;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, newToken);
    await p.setString(_kUserName, newUserName);
  }

  static Future<void> saveServer(String url) async {
    apiBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final p = await SharedPreferences.getInstance();
    await p.setString(_kServer, apiBaseUrl);
  }

  static Future<void> clear() async {
    token = null;
    userName = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUserName);
  }
}
