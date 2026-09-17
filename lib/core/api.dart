import 'dart:convert';
import 'dart:io';

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
  /// Absolute URL of the attached image, if any.
  final String? imageUrl;
  final DateTime sentAt;
  /// For admin messages: whether the user has opened them (MessageRead).
  bool isRead;

  ChatMessage.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(),
        sender = j['sender'] as String,
        message = j['message'] as String? ?? '',
        imageUrl = _resolveImageUrl(j['imageUrl'] as String?),
        sentAt = DateTime.parse(j['sentAt'] as String),
        isRead = j['isRead'] == true;

  bool get fromAdmin => sender == 'admin';
  bool get hasImage => imageUrl != null;

  /// Server stores "/uploads/…" (relative) so each client prefixes its own
  /// host; older rows with absolute URLs pass through unchanged.
  static String? _resolveImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('/') ? '${Session.apiBaseUrl}$raw' : raw;
  }
}

/// HTTP client for api/v3/mobile/admin-chat.
class Api {
  /// Mirrors the backend limit (SupportChatService.MaxImageBytes).
  static const int maxImageBytes = 10 * 1024 * 1024;

  static Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${Session.apiBaseUrl}/api/v3/mobile/admin-chat$path')
          .replace(queryParameters: q);

  static Map<String, String> get _authHeader => {
        if (Session.token != null) 'Authorization': 'Bearer ${Session.token}',
      };

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        ..._authHeader,
      };

  static dynamic _decode(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final msg = body is Map && body['error'] != null
        ? _humanError(body['error'].toString())
        : 'HTTP ${r.statusCode}';
    throw Exception(msg);
  }

  static String _humanError(String code) => switch (code) {
        'image_required' => 'لم يتم اختيار صورة',
        'image_too_large' => 'حجم الصورة أكبر من 10 ميغابايت',
        'invalid_image' => 'نوع الملف غير مدعوم (jpg, png, webp, gif, heic)',
        _ => code,
      };

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

  /// Uploads [image] with an optional [caption] as one message
  /// (multipart POST /send-image). Returns the created message.
  static Future<ChatMessage> sendImage(
      int userId, String userType, File image, String caption) async {
    if (await image.length() > maxImageBytes) {
      throw Exception(_humanError('image_too_large'));
    }
    final req = http.MultipartRequest('POST', _u('/send-image'))
      ..headers.addAll(_authHeader)
      ..fields['userId'] = '$userId'
      ..fields['userType'] = userType
      ..fields['caption'] = caption
      ..files.add(await http.MultipartFile.fromPath('image', image.path));
    final streamed = await req.send().timeout(const Duration(seconds: 90));
    final r = await http.Response.fromStream(streamed);
    return ChatMessage.fromJson(_decode(r) as Map<String, dynamic>);
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
