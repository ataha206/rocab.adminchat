import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/realtime.dart';
import '../core/session.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'signups_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with WidgetsBindingObserver {
  List<Conversation> _items = const [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;
  StreamSubscription? _resyncSub;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    Realtime.instance.connect();
    // Any incoming message re-sorts/updates the list.
    _sub = Realtime.instance.onMessage.listen((_) => _load());
    _resyncSub = Realtime.instance.onResync.listen((_) => _load());
    // Safety net when the socket is down.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Realtime.instance.ensureConnected();
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _resyncSub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await Api.conversations();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } on SessionExpiredException {
      // Token expired or rejected: back to the login screen instead of a
      // bare "HTTP 401" with no way out.
      await Realtime.instance.disconnect();
      await Session.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('انتهت صلاحية الجلسة، سجّل الدخول مرة أخرى')));
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثات الدعم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'طلبات اشتراك السائقين',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignupsScreen())),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') {
                await Realtime.instance.disconnect();
                await Session.clear();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  enabled: false, child: Text(Session.userName ?? '')),
              const PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Icon(Icons.forum_outlined,
                            size: 56,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        Center(
                            child: Text(_error ?? 'لا محادثات مفتوحة',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline))),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = _items[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: c.userType == 'driver'
                                ? Colors.indigo.shade100
                                : Colors.teal.shade100,
                            child: Icon(
                                c.userType == 'driver'
                                    ? Icons.local_taxi
                                    : Icons.person,
                                size: 20),
                          ),
                          title: Text(c.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (c.details.isNotEmpty)
                                Text(c.details,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF128C7E))),
                              Text(c.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                          isThreeLine: c.details.isNotEmpty,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${c.lastSentAt.toLocal()}'.substring(11, 16),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.unreadCount > 0
                                      ? const Color(0xFF25D366)
                                      : Colors.grey,
                                  fontWeight: c.unreadCount > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (c.unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF25D366),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text('${c.unreadCount}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ChatScreen(conversation: c)));
                            _load();
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
