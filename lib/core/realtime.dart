import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import 'session.dart';

/// SignalR connection to SupportChatHub as the "admin" group.
/// Emits on [onMessage] for every support message (any conversation).
///
/// Android/iOS cut the socket when the app sits in the background; the
/// client's automatic reconnect gives up after its retry schedule, so the
/// screens call [ensureConnected] on resume and reload on [onResync], which
/// fires every time the hub comes back after a gap (messages that arrived
/// meanwhile were never pushed to us).
class Realtime {
  static final Realtime instance = Realtime._();
  Realtime._();

  HubConnection? _hub;
  Timer? _retry;
  bool _everConnected = false;
  final StreamController<Map<String, dynamic>> _messages =
      StreamController.broadcast();
  final StreamController<int> _reads = StreamController.broadcast();
  final StreamController<void> _resync = StreamController.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messages.stream;

  /// Message ids the user has opened (hub "MessageRead").
  Stream<int> get onMessageRead => _reads.stream;

  /// The hub reconnected after being down: reload whatever is on screen.
  Stream<void> get onResync => _resync.stream;

  bool get isConnected => _hub?.state == HubConnectionState.Connected;

  Future<void> connect() async {
    if (_hub != null) return ensureConnected();
    final hub = HubConnectionBuilder()
        .withUrl('${Session.apiBaseUrl}/supportChatHub?userType=admin')
        .withAutomaticReconnect(
            retryDelays: [0, 2000, 5000, 10000, 30000, 60000])
        .build();
    hub.on('ReceiveMessage', (args) {
      final a = args;
      if (a != null && a.isNotEmpty && a.first is Map) {
        _messages.add(Map<String, dynamic>.from(a.first as Map));
      }
    });
    hub.on('MessageRead', (args) {
      final a = args;
      if (a != null && a.isNotEmpty && a.first is num) {
        _reads.add((a.first as num).toInt());
      }
    });
    hub.onreconnected(({connectionId}) => _resync.add(null));
    // Automatic reconnect exhausted (or server closed us): try again later
    // ourselves instead of staying silent until the app restarts.
    hub.onclose(({error}) => _scheduleRetry());
    _hub = hub;
    await _start();
  }

  /// Reconnects when the automatic policy has given up (typical after the app
  /// spent a while in the background). Safe to call on every resume.
  Future<void> ensureConnected() async {
    final hub = _hub;
    if (hub == null) return connect();
    switch (hub.state) {
      case HubConnectionState.Connected:
      case HubConnectionState.Connecting:
      case HubConnectionState.Reconnecting:
        return;
      default:
        await _start();
    }
  }

  Future<void> _start() async {
    final hub = _hub;
    if (hub == null) return;
    _retry?.cancel();
    try {
      await hub.start();
      if (_everConnected) _resync.add(null);
      _everConnected = true;
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_hub == null) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 15), ensureConnected);
  }

  Future<void> disconnect() async {
    _retry?.cancel();
    final hub = _hub;
    _hub = null;
    _everConnected = false;
    await hub?.stop();
  }
}
