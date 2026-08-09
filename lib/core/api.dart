import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session.dart';

class Conversation {
  final int userId;
  final String userType;
  final String name;
  final String? mobile;
  final String? city;
  final String lastMessage;
  final DateTime lastSentAt;
  final int unreadCount;

  Conversation.fromJson(Map<String, dynamic> j)
      : userId = (j['userId'] as num).toInt(),
        userType = j['userType'] as String,
        name = j['name'] as String? ?? '؟',
        mobile = j['mobile'] as String?,
        city = j['city'] as String?,
        lastMessage = j['lastMessage'] as String? ?? '',
        lastSentAt = DateTime.parse(j['lastSentAt'] as String),
        unreadCount = (j['unreadCount'] as num?)?.toInt() ?? 0;

  /// "المدينة • الهاتف" — whichever parts exist.
  String get details => [
        if (city != null && city!.isNotEmpty) city!,
        if (mobile != null && mobile!.isNotEmpty) mobile!,
      ].join(' • ');
}

class ChatMessage {
  final int id;
  final String sender;
  final String message;
  final DateTime sentAt;

  ChatMessage.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(),
        sender = j['sender'] as String,
        message = j['message'] as String? ?? '',
        sentAt = DateTime.parse(j['sentAt'] as String);

  bool get fromAdmin => sender == 'admin';
}

/// HTTP client for api/v3/mobile/admin-chat.
class Api {
  static Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${Session.apiBaseUrl}/api/v3/mobile/admin-chat$path')
          .replace(queryParameters: q);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (Session.token != null) 'Authorization': 'Bearer ${Session.token}',
      };

  static dynamic _decode(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final msg = body is Map && body['error'] != null
        ? body['error'].toString()
        : 'HTTP ${r.statusCode}';
    throw Exception(msg);
  }

  static Future<void> login(String userName, String password) async {
    final r = await http.post(_u('/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userName': userName, 'password': password}));
    final j = _decode(r) as Map<String, dynamic>;
    await Session.save(j['token'] as String, j['userName'] as String);
  }

  static Future<List<Conversation>> conversations() async {
    final r = await http.get(_u('/conversations'), headers: _headers);
    return (_decode(r) as List)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ChatMessage>> messages(int userId, String userType) async {
    final r = await http.get(
        _u('/messages', {'userId': '$userId', 'userType': userType}),
        headers: _headers);
    return (_decode(r) as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> send(int userId, String userType, String message) async {
    _decode(await http.post(_u('/send'),
        headers: _headers,
        body: jsonEncode(
            {'userId': userId, 'userType': userType, 'message': message})));
  }

  static Future<void> registerDevice(String pushToken) async {
    _decode(await http.post(_u('/register-device'),
        headers: _headers, body: jsonEncode({'pushToken': pushToken})));
  }

  static Future<void> seen(int userId, String userType) async {
    _decode(await http.post(_u('/seen'),
        headers: _headers,
        body: jsonEncode({'userId': userId, 'userType': userType})));
  }

  static Future<void> close(int userId, String userType) async {
    _decode(await http.post(_u('/close'),
        headers: _headers,
        body: jsonEncode({'userId': userId, 'userType': userType})));
  }
}
