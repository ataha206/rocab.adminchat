import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/realtime.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> _messages = const [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  StreamSubscription? _sub;

  Conversation get c => widget.conversation;

  @override
  void initState() {
    super.initState();
    _load();
    Api.seen(c.userId, c.userType);
    _sub = Realtime.instance.onMessage.listen((m) {
      if (m['userId'] == c.userId &&
          (m['userType'] as String?)?.toLowerCase() == c.userType) {
        _load();
        Api.seen(c.userId, c.userType);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final msgs = await Api.messages(c.userId, c.userType);
      if (!mounted) return;
      setState(() => _messages = msgs);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Api.send(c.userId, c.userType, text);
      _input.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق المحادثة؟'),
        content: const Text('تُفتح تلقائيًا إذا راسل المستخدم مجددًا.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إغلاق')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.close(c.userId, c.userType);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${c.name} (${c.userType == 'driver' ? 'سائق' : 'راكب'})',
                style: const TextStyle(fontSize: 17)),
            if (c.details.isNotEmpty)
              Text(c.details,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.task_alt),
              tooltip: 'إغلاق المحادثة',
              onPressed: _close),
        ],
      ),
      body: Container(
        color: const Color(0xFFECE5DD),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(10),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final mine = m.fromAdmin;
                  return Align(
                    alignment:
                        mine ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding:
                          const EdgeInsets.fromLTRB(10, 6, 10, 4),
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: mine ? const Color(0xFFDCF8C6) : Colors.white,
                        borderRadius: BorderRadius.only(
                          topRight: const Radius.circular(12),
                          topLeft: const Radius.circular(12),
                          bottomRight: Radius.circular(mine ? 12 : 2),
                          bottomLeft: Radius.circular(mine ? 2 : 12),
                        ),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 1,
                              offset: Offset(0, 1)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.message,
                              style: const TextStyle(
                                  fontSize: 15, color: Color(0xFF111B21))),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${m.sentAt.toLocal()}'.substring(11, 16),
                                style: const TextStyle(
                                    fontSize: 10.5, color: Color(0xFF667781)),
                              ),
                              if (mine) ...[
                                const SizedBox(width: 3),
                                const Icon(Icons.done_all,
                                    size: 14, color: Color(0xFF53BDEB)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 1,
                                offset: Offset(0, 1)),
                          ],
                        ),
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 5,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'اكتب ردك…',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FloatingActionButton.small(
                      heroTag: 'send',
                      onPressed: _sending ? null : _send,
                      shape: const CircleBorder(),
                      child: _sending
                          ? const SizedBox(
                              height: 16, width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
