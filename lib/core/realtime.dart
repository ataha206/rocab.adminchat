import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import 'session.dart';

/// SignalR connection to SupportChatHub as the "admin" group.
/// Emits on [onMessage] for every support message (any conversation).
class Realtime {
  static final Realtime instance = Realtime._();
  Realtime._();

  HubConnection? _hub;
  final StreamController<Map<String, dynamic>> _messages =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messages.stream;

  Future<void> connect() async {
    if (_hub != null) return;
    final hub = HubConnectionBuilder()
        .withUrl('${Session.apiBaseUrl}/supportChatHub?userType=admin')
        .withAutomaticReconnect()
        .build();
    hub.on('ReceiveMessage', (args) {
      final a = args;
      if (a != null && a.isNotEmpty && a.first is Map) {
        _messages.add(Map<String, dynamic>.from(a.first as Map));
      }
    });
    _hub = hub;
    try {
      await hub.start();
    } catch (_) {
      // Reconnect handles later attempts; polling still refreshes lists.
    }
  }

  Future<void> disconnect() async {
    await _hub?.stop();
    _hub = null;
  }
}
