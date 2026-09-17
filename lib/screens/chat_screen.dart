import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final _picker = ImagePicker();
  bool _sending = false;
  StreamSubscription? _sub;
  StreamSubscription? _readSub;

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
    // The user opened one of our messages → flip its tick without a reload.
    _readSub = Realtime.instance.onMessageRead.listen((id) {
      final i = _messages.indexWhere((m) => m.id == id);
      if (i == -1 || _messages[i].isRead || !mounted) return;
      setState(() => _messages[i].isRead = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _readSub?.cancel();
    _input.dispose();
    _scroll.dispose();
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

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', ''))));
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
      _showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Gallery/camera sheet → preview with caption → upload.
  Future<void> _attach() async {
    if (_sending) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('تصوير'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
        requestFullMetadata: false,
      );
    } catch (_) {
      _showError('تعذر الوصول إلى الصور، تحقق من الأذونات');
      return;
    }
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    final caption = await _ImagePreviewSheet.show(context, file, _input.text);
    if (caption == null || !mounted) return; // cancelled

    setState(() => _sending = true);
    try {
      await Api.sendImage(c.userId, c.userType, file, caption.trim());
      _input.clear();
      await _load();
    } catch (e) {
      _showError(e);
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

  void _openImage(String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenImage(url: url),
    ));
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
                itemBuilder: (context, i) => _Bubble(
                  message: _messages[i],
                  onImageTap: _openImage,
                ),
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
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
                            IconButton(
                              tooltip: 'إرفاق صورة',
                              onPressed: _sending ? null : _attach,
                              icon: const Icon(Icons.photo_camera_back_outlined,
                                  color: Color(0xFF54656F)),
                            ),
                          ],
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

/// WhatsApp-style bubble; renders the image (if any) above the caption.
class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<String> onImageTap;
  const _Bubble({required this.message, required this.onImageTap});

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.fromAdmin;
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: m.hasImage
            ? const EdgeInsets.fromLTRB(4, 4, 4, 4)
            : const EdgeInsets.fromLTRB(10, 6, 10, 4),
        constraints: BoxConstraints(maxWidth: maxWidth),
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
                color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.hasImage)
              GestureDetector(
                onTap: () => onImageTap(m.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: _NetworkImage(url: m.imageUrl!, width: maxWidth - 8),
                ),
              ),
            if (m.message.isNotEmpty)
              Padding(
                padding: m.hasImage
                    ? const EdgeInsets.fromLTRB(6, 6, 6, 0)
                    : EdgeInsets.zero,
                child: Text(m.message,
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF111B21))),
              ),
            const SizedBox(height: 2),
            Padding(
              padding: m.hasImage
                  ? const EdgeInsets.fromLTRB(6, 0, 6, 2)
                  : EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${m.sentAt.toLocal()}'.substring(11, 16),
                    style: const TextStyle(
                        fontSize: 10.5, color: Color(0xFF667781)),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 3),
                    // Single grey tick = delivered, double blue = user opened it.
                    Icon(m.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: m.isRead
                            ? const Color(0xFF53BDEB)
                            : const Color(0xFF8696A0)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;
  final double width;
  const _NetworkImage({required this.url, required this.width});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: width,
      fit: BoxFit.cover,
      loadingBuilder: (ctx, child, progress) => progress == null
          ? child
          : SizedBox(
              width: width,
              height: width * 0.75,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
      errorBuilder: (ctx, _, _) => SizedBox(
        width: width,
        height: 120,
        child: const Center(
            child: Icon(Icons.broken_image_outlined,
                color: Color(0xFF667781), size: 36)),
      ),
    );
  }
}

/// Bottom sheet: picked image + editable caption. Resolves with the caption
/// (possibly empty) on send, null on cancel.
class _ImagePreviewSheet extends StatefulWidget {
  final File file;
  final String initialCaption;
  const _ImagePreviewSheet(
      {required this.file, required this.initialCaption});

  static Future<String?> show(
          BuildContext context, File file, String initialCaption) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            _ImagePreviewSheet(file: file, initialCaption: initialCaption),
      );

  @override
  State<_ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewSheetState extends State<_ImagePreviewSheet> {
  late final _caption = TextEditingController(text: widget.initialCaption);

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(widget.file, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'أضف تعليقًا (اختياري)',
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _caption.text),
                  icon: const Icon(Icons.send),
                  label: const Text('إرسال'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : const CircularProgressIndicator(color: Colors.white),
            errorBuilder: (ctx, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64),
          ),
        ),
      ),
    );
  }
}
