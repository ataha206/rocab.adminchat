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

/// Profile card of a rider or driver (GET /user).
class UserProfile {
  final int userId;
  final String userType;
  final String name;
  final String? mobile;
  final String? email;
  final String? city;
  final String status;
  final bool isBlocked;
  final DateTime? joinedAt;
  final DateTime? lastRideAt;
  final DateTime? lastActivityAt;
  final double walletBalance;
  final double? bonusBalance;
  final DateTime? bonusExpiresAt;
  final String? currency;
  final int? points;
  final int? totalPoints;
  final String? classification;
  final String? appVersion;
  final String? device;
  final double? totalKm;
  final int ridesTotal;
  final int ridesCompleted;
  final int ridesCancelled;
  // Driver only.
  final String? vehiclePlate;
  final String? vehicleDescription;
  final String? vehicleType;
  final String? partner;
  final String? nationalId;
  final String? licenseNumber;
  final DateTime? licenseExpiresAt;

  bool get isDriver => userType == 'driver';

  UserProfile.fromJson(Map<String, dynamic> j)
      : userId = (j['userId'] as num).toInt(),
        userType = j['userType'] as String,
        name = j['name'] as String? ?? '؟',
        mobile = j['mobile'] as String?,
        email = j['email'] as String?,
        city = j['city'] as String?,
        status = j['status'] as String? ?? '—',
        isBlocked = j['isBlocked'] == true,
        joinedAt = _date(j['joinedAt']),
        lastRideAt = _date(j['lastRideAt']),
        lastActivityAt = _date(j['lastActivityAt']),
        walletBalance = (j['walletBalance'] as num?)?.toDouble() ?? 0,
        bonusBalance = (j['bonusBalance'] as num?)?.toDouble(),
        bonusExpiresAt = _date(j['bonusExpiresAt']),
        currency = j['currency'] as String?,
        points = (j['points'] as num?)?.toInt(),
        totalPoints = (j['totalPoints'] as num?)?.toInt(),
        classification = j['classification'] as String?,
        appVersion = j['appVersion'] as String?,
        device = j['device'] as String?,
        totalKm = (j['totalKm'] as num?)?.toDouble(),
        ridesTotal = (j['rides']?['total'] as num?)?.toInt() ?? 0,
        ridesCompleted = (j['rides']?['completed'] as num?)?.toInt() ?? 0,
        ridesCancelled = (j['rides']?['cancelled'] as num?)?.toInt() ?? 0,
        vehiclePlate = j['vehicle']?['plate'] as String?,
        vehicleDescription = j['vehicle']?['description'] as String?,
        vehicleType = j['vehicle']?['type'] as String?,
        partner = j['partner'] as String?,
        nationalId = j['nationalId'] as String?,
        licenseNumber = j['licenseNumber'] as String?,
        licenseExpiresAt = _date(j['licenseExpiresAt']);
}

/// One ride as seen from the chatted user's side (GET /rides).
class UserRide {
  final int id;
  final DateTime? createdAt;
  final DateTime? endedAt;
  final DateTime? cancelledAt;
  final String statusCode;
  final String status;
  final String? pickAddress;
  final String? dropAddress;
  final double? amount;
  final double? paidAmount;
  final double? discount;
  final String? currency;
  final double? distanceKm;
  final String? duration;
  final String paymentMethod;
  final String? bookedFrom;
  final int? counterpartId;
  final String? counterpartName;
  final String? counterpartMobile;
  final double? rating;
  final String? cancelReason;
  final bool isScheduled;
  final DateTime? scheduledAt;

  bool get isCompleted => statusCode == 'E';
  bool get isCancelled => statusCode == 'C' || statusCode == 'R';

  UserRide.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(),
        createdAt = _date(j['createdAt']),
        endedAt = _date(j['endedAt']),
        cancelledAt = _date(j['cancelledAt']),
        statusCode = (j['statusCode'] as String? ?? '').toUpperCase(),
        status = j['status'] as String? ?? '—',
        pickAddress = j['pickAddress'] as String?,
        dropAddress = j['dropAddress'] as String?,
        amount = (j['amount'] as num?)?.toDouble(),
        paidAmount = (j['paidAmount'] as num?)?.toDouble(),
        discount = (j['discount'] as num?)?.toDouble(),
        currency = j['currency'] as String?,
        distanceKm = (j['distanceKm'] as num?)?.toDouble(),
        duration = j['duration'] as String?,
        paymentMethod = j['paymentMethod'] as String? ?? '',
        bookedFrom = j['bookedFrom'] as String?,
        counterpartId = (j['counterpartId'] as num?)?.toInt(),
        counterpartName = j['counterpartName'] as String?,
        counterpartMobile = j['counterpartMobile'] as String?,
        rating = (j['rating'] as num?)?.toDouble(),
        cancelReason = j['cancelReason'] as String?,
        isScheduled = j['isScheduled'] == true,
        scheduledAt = _date(j['scheduledAt']);
}

/// One wallet movement (GET /wallet). Positive amount = credit.
class WalletEntry {
  final int id;
  final DateTime createdAt;
  final double amount;
  final double? balanceBefore;
  final double? balanceAfter;
  final String? type;
  final String? notes;
  final int? rideId;
  final bool isBonus;

  bool get isCredit => amount >= 0;

  WalletEntry.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(),
        createdAt = DateTime.parse(j['createdAt'] as String),
        amount = (j['amount'] as num?)?.toDouble() ?? 0,
        balanceBefore = (j['balanceBefore'] as num?)?.toDouble(),
        balanceAfter = (j['balanceAfter'] as num?)?.toDouble(),
        type = j['type'] as String?,
        notes = j['notes'] as String?,
        rideId = (j['rideId'] as num?)?.toInt(),
        isBonus = j['isBonus'] == true;
}

/// A pending driver signup request (GET /signups, GET /signups/{id}).
class SignupRequest {
  final int id;
  /// Null for requests older than the CreatedAt column.
  final DateTime? createdAt;
  final String name;
  final String mobile;
  final String? nationalId;
  final String? nationality;
  final String? birthdate;
  final String? gender;
  final String? city;
  final String? district;
  final String? plate;
  final String? vehicle;
  final String? licenseType;
  final bool isPtt;
  final bool isPending;
  final int? driverId;
  final String? rejectionReason;
  /// Photo types present: 1 personal, 2 ID, 3 vehicle, 5 driver licence, 6 vehicle licence.
  final List<int> images;

  SignupRequest.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(),
        createdAt = _date(j['createdAt']),
        name = j['name'] as String? ?? '؟',
        mobile = j['mobile'] as String? ?? '',
        nationalId = j['nationalId'] as String?,
        nationality = j['nationality'] as String?,
        birthdate = j['birthdate'] as String?,
        gender = j['gender'] as String?,
        city = j['city'] as String?,
        district = j['district'] as String?,
        plate = j['plate'] as String?,
        vehicle = j['vehicle'] as String?,
        licenseType = j['licenseType'] as String?,
        isPtt = j['isPtt'] == true,
        isPending = j['isPending'] != false,
        driverId = (j['driverId'] as num?)?.toInt(),
        rejectionReason = j['rejectionReason'] as String?,
        images = ((j['images'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList();

  static String imageTitle(int type) => switch (type) {
        1 => 'صورة شخصية',
        2 => 'الهوية',
        3 => 'المركبة',
        5 => 'رخصة السائق',
        6 => 'رخصة المركبة',
        _ => 'صورة',
      };
}

class SignupPage {
  final int total;
  final List<SignupRequest> items;
  SignupPage.fromJson(Map<String, dynamic> j)
      : total = (j['total'] as num?)?.toInt() ?? 0,
        items = ((j['items'] as List?) ?? const [])
            .map((e) => SignupRequest.fromJson(e as Map<String, dynamic>))
            .toList();
}

class IdName {
  final int id;
  final String name;
  IdName.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(),
        name = j['name'] as String? ?? '${j['id']}';
}

/// Partners and service types for the accept dialog.
class SignupOptions {
  final List<IdName> partners;
  final List<IdName> serviceTypes;
  SignupOptions.fromJson(Map<String, dynamic> j)
      : partners = ((j['partners'] as List?) ?? const [])
            .map((e) => IdName.fromJson(e as Map<String, dynamic>))
            .toList(),
        serviceTypes = ((j['serviceTypes'] as List?) ?? const [])
            .map((e) => IdName.fromJson(e as Map<String, dynamic>))
            .toList();
}

DateTime? _date(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

/// The saved bearer token is no longer accepted: the user has to sign in again.
class SessionExpiredException implements Exception {
  @override
  String toString() => 'انتهت صلاحية الجلسة، سجّل الدخول مرة أخرى';
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
    final hasError = body is Map && body['error'] != null;
    // A bare 401 (no error body) is the server rejecting our bearer token:
    // expired (30-day lifetime) or signed with another secret. Login failures
    // carry an error message and stay ordinary exceptions.
    if (r.statusCode == 401 && !hasError) throw SessionExpiredException();
    final msg = hasError ? _humanError(body['error'].toString()) : 'HTTP ${r.statusCode}';
    throw Exception(msg);
  }

  static String _humanError(String code) => switch (code) {
        'image_required' => 'لم يتم اختيار صورة',
        'image_too_large' => 'حجم الصورة أكبر من 10 ميغابايت',
        'invalid_image' => 'نوع الملف غير مدعوم (jpg, png, webp, gif, heic)',
        'user_not_found' => 'المستخدم غير موجود',
        'signup_not_found' => 'طلب الاشتراك غير موجود أو تمت معالجته',
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

  // ---- user context (profile / rides / wallet) ----

  static Future<UserProfile> userProfile(int userId, String userType) async {
    final r = await http.get(
        _u('/user', {'userId': '$userId', 'userType': userType}),
        headers: _headers);
    return UserProfile.fromJson(_decode(r) as Map<String, dynamic>);
  }

  static Future<List<UserRide>> userRides(int userId, String userType,
      {int skip = 0, int take = 30}) async {
    final r = await http.get(
        _u('/rides', {
          'userId': '$userId',
          'userType': userType,
          'skip': '$skip',
          'take': '$take',
        }),
        headers: _headers);
    return (_decode(r) as List)
        .map((e) => UserRide.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<WalletEntry>> userWallet(int userId, String userType,
      {int skip = 0, int take = 30}) async {
    final r = await http.get(
        _u('/wallet', {
          'userId': '$userId',
          'userType': userType,
          'skip': '$skip',
          'take': '$take',
        }),
        headers: _headers);
    return (_decode(r) as List)
        .map((e) => WalletEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- driver signup requests ----

  static Future<SignupPage> signups(
      {String? query, int skip = 0, int take = 30}) async {
    final r = await http.get(
        _u('/signups', {
          if (query != null && query.isNotEmpty) 'q': query,
          'skip': '$skip',
          'take': '$take',
        }),
        headers: _headers);
    return SignupPage.fromJson(_decode(r) as Map<String, dynamic>);
  }

  static Future<SignupRequest> signup(int id) async {
    final r = await http.get(_u('/signups/$id'), headers: _headers);
    return SignupRequest.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// URL + headers for Image.network: the image endpoint needs the bearer.
  static String signupImageUrl(int id, int imageType) =>
      _u('/signups/$id/image/$imageType').toString();
  static Map<String, String> get imageHeaders => _authHeader;

  static Future<SignupOptions> signupOptions() async {
    final r = await http.get(_u('/signups/options'), headers: _headers);
    return SignupOptions.fromJson(_decode(r) as Map<String, dynamic>);
  }

  static Future<void> acceptSignup(int id, int partnerId, int serviceId) async {
    _decode(await http
        .post(_u('/signups/$id/accept'),
            headers: _headers,
            body: jsonEncode({'partnerId': partnerId, 'serviceId': serviceId}))
        .timeout(const Duration(seconds: 90)));
  }

  static Future<void> rejectSignup(int id, String reason) async {
    _decode(await http.post(_u('/signups/$id/reject'),
        headers: _headers, body: jsonEncode({'reason': reason})));
  }
}
