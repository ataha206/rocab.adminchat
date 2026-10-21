import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';

final _dateTime = DateFormat('yyyy/MM/dd HH:mm');
String _fmtDate(DateTime? d) => d == null ? '—' : _dateTime.format(d.toLocal());

/// Pending driver signup requests: list, search, open one to accept or reject.
class SignupsScreen extends StatefulWidget {
  const SignupsScreen({super.key});

  @override
  State<SignupsScreen> createState() => _SignupsScreenState();
}

class _SignupsScreenState extends State<SignupsScreen> {
  static const int _pageSize = 30;

  final List<SignupRequest> _items = [];
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _total = 0;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await Api.signups(query: _search.text.trim(), take: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _hasMore = page.items.length == _pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await Api.signups(
          query: _search.text.trim(), skip: _items.length, take: _pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
        _hasMore = page.items.length == _pageSize;
      });
    } catch (_) {
      // Keep the page; scrolling again retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(SignupRequest r) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => SignupDetailScreen(id: r.id, title: r.name),
    ));
    // Accepted or rejected → it is no longer pending; drop it without a refetch.
    if (changed == true && mounted) {
      setState(() {
        _items.removeWhere((x) => x.id == r.id);
        _total = _total > 0 ? _total - 1 : 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F5),
      appBar: AppBar(
        title: Text(_total > 0 ? 'طلبات الاشتراك ($_total)' : 'طلبات الاشتراك'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم، الهاتف، الهوية أو اللوحة',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _reload();
                        }),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Color(0xFF667781)),
              const SizedBox(height: 8),
              Text(_errText(_error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('لا توجد طلبات اشتراك معلّقة',
            style: TextStyle(color: Color(0xFF667781))),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final r = _items[i];
          return _SignupTile(request: r, onTap: () => _open(r));
        },
      ),
    );
  }
}

class _SignupTile extends StatelessWidget {
  final SignupRequest request;
  final VoidCallback onTap;
  const _SignupTile({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final line2 = [
      if (r.city != null && r.city!.isNotEmpty) r.city!,
      if (r.district != null && r.district!.isNotEmpty) r.district!,
      r.mobile,
    ].join(' • ');
    final line3 = [
      if (r.plate != null && r.plate!.isNotEmpty) r.plate!,
      if (r.vehicle != null && r.vehicle!.isNotEmpty) r.vehicle!,
    ].join(' • ');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF128C7E),
          child: Icon(r.isPtt ? Icons.radio : Icons.local_taxi, color: Colors.white),
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(r.name,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('#${r.id}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF667781))),
                if (r.createdAt != null)
                  Text(_fmtDate(r.createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF667781))),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line2, style: const TextStyle(fontSize: 12.5)),
            if (r.isPtt)
              const Text('مستخدم لاسلكي (PTT) بدون مركبة',
                  style: TextStyle(fontSize: 12, color: Colors.indigo))
            else if (line3.isNotEmpty)
              Text(line3,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF667781))),
          ],
        ),
        trailing: const Icon(Icons.chevron_left),
      ),
    );
  }
}

String _errText(Object e) => e.toString().replaceFirst('Exception: ', '');

// ================================================================ detail

/// One request with its photos; accept (partner + service type) or reject
/// (reason). Pops with `true` once the request is no longer pending.
class SignupDetailScreen extends StatefulWidget {
  final int id;
  final String title;
  const SignupDetailScreen({super.key, required this.id, required this.title});

  @override
  State<SignupDetailScreen> createState() => _SignupDetailScreenState();
}

class _SignupDetailScreenState extends State<SignupDetailScreen> {
  SignupRequest? _r;
  Object? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.signup(widget.id);
      if (!mounted) return;
      setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    SignupOptions options;
    try {
      options = await Api.signupOptions();
    } catch (e) {
      _snack(_errText(e));
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final choice = await showDialog<(int, int)>(
      context: context,
      builder: (_) => _AcceptDialog(options: options, isPtt: _r?.isPtt == true),
    );
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await Api.acceptSignup(widget.id, choice.$1, choice.$2);
      if (!mounted) return;
      _snack('تم قبول الطلب وإنشاء حساب السائق');
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack(_errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await Api.rejectSignup(widget.id, reason.trim());
      if (!mounted) return;
      _snack('تم رفض الطلب وإبلاغ مقدّمه برسالة نصية');
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack(_errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openImage(int type) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullImage(
        url: Api.signupImageUrl(widget.id, type),
        title: SignupRequest.imageTitle(type),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F5),
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontSize: 17))),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null || r == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Color(0xFF667781)),
                    const SizedBox(height: 8),
                    Text(_error == null ? 'تعذر التحميل' : _errText(_error!),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة')),
                  ],
                ),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                children: [
                  if (!r.isPending)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        r.driverId != null
                            ? 'هذا الطلب مقبول مسبقاً (رقم السائق ${r.driverId}).'
                            : r.rejectionReason != null
                                ? 'هذا الطلب مرفوض مسبقاً. السبب: ${r.rejectionReason}'
                                : 'هذا الطلب تمت معالجته مسبقاً.',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  _Section(title: 'المتقدّم', children: [
                    _Row('رقم الطلب', '#${r.id}'),
                    _Row('تاريخ الطلب', _fmtDate(r.createdAt)),
                    _Row('الاسم', r.name),
                    _Row('الهاتف', r.mobile, copyable: true),
                    _Row('رقم الهوية', r.nationalId, copyable: true),
                    _Row('الجنسية', r.nationality),
                    _Row('تاريخ الميلاد', r.birthdate),
                    _Row('الجنس', r.gender),
                    _Row('المدينة', r.city),
                    _Row('المنطقة', r.district),
                    _Row('نوع الرخصة', r.licenseType),
                  ]),
                  if (r.isPtt)
                    const _Section(title: 'المركبة', children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('طلب من تطبيق العمليات: مستخدم لاسلكي بدون مركبة.',
                            style: TextStyle(color: Colors.indigo)),
                      ),
                    ])
                  else
                    _Section(title: 'المركبة', children: [
                      _Row('رقم اللوحة', r.plate, copyable: true),
                      _Row('المركبة', r.vehicle),
                    ]),
                  _Section(title: 'المستندات', children: [
                    if (r.images.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('لا توجد صور مرفقة',
                            style: TextStyle(color: Color(0xFF667781))),
                      )
                    else
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.25,
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        children: [
                          for (final t in r.images)
                            _Thumb(
                              url: Api.signupImageUrl(r.id, t),
                              title: SignupRequest.imageTitle(t),
                              onTap: () => _openImage(t),
                            ),
                        ],
                      ),
                  ]),
                ],
              ),
            ),
          if (_busy)
            const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
      bottomNavigationBar: r == null || !r.isPending
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('رفض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _accept,
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        icon: const Icon(Icons.check),
                        label: const Text('قبول الطلب'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF075E54))),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  final bool copyable;
  const _Row(this.label, this.value, {this.copyable = false});

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.trim().isEmpty) return const SizedBox.shrink();
    final text = Text(v,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111B21)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(color: Color(0xFF667781)))),
          Expanded(
            child: copyable
                ? InkWell(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: v));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('تم نسخ $v'),
                          duration: const Duration(seconds: 1)));
                    },
                    child: text)
                : text,
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final String title;
  final VoidCallback onTap;
  const _Thumb({required this.url, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              headers: Api.imageHeaders,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, p) => p == null
                  ? child
                  : const ColoredBox(
                      color: Color(0xFFE9EDEF),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorBuilder: (ctx, _, _) => const ColoredBox(
                color: Color(0xFFE9EDEF),
                child: Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Color(0xFF667781), size: 32)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black45,
                child: Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullImage extends StatelessWidget {
  final String url;
  final String title;
  const _FullImage({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title, style: const TextStyle(fontSize: 16))),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 6,
          child: Image.network(
            url,
            headers: Api.imageHeaders,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, p) => p == null
                ? child
                : const CircularProgressIndicator(color: Colors.white),
            errorBuilder: (ctx, _, _) => const Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}

/// Partner + service type pickers. Resolves with (partnerId, serviceId).
class _AcceptDialog extends StatefulWidget {
  final SignupOptions options;
  final bool isPtt;
  const _AcceptDialog({required this.options, required this.isPtt});

  @override
  State<_AcceptDialog> createState() => _AcceptDialogState();
}

class _AcceptDialogState extends State<_AcceptDialog> {
  int? _partner;
  int? _service;

  @override
  void initState() {
    super.initState();
    // PTT requests have one sensible service type; preselect it when found.
    if (widget.isPtt) {
      for (final s in widget.options.serviceTypes) {
        if (s.name.toUpperCase().contains('PTT')) {
          _service = s.id;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    return AlertDialog(
      title: const Text('قبول طلب الاشتراك'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _partner,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المكتب / الشريك'),
            items: [
              for (final p in o.partners)
                DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _partner = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _service,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'نوع الخدمة'),
            items: [
              for (final s in o.serviceTypes)
                DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _service = v),
          ),
          const SizedBox(height: 8),
          const Text('سيتم إنشاء حساب السائق وإرسال رسالة نصية له.',
              style: TextStyle(fontSize: 12, color: Color(0xFF667781))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _partner == null || _service == null
              ? null
              : () => Navigator.pop(context, (_partner!, _service!)),
          child: const Text('قبول'),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();
  static const _presets = [
    'الصور غير واضحة',
    'بيانات المركبة غير مكتملة',
    'رخصة القيادة منتهية',
    'لا تتوفر خدمة في منطقتك حالياً',
  ];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('رفض طلب الاشتراك'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in _presets)
                ActionChip(
                  label: Text(p, style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _reason.text = p),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'السبب (يصل للمتقدّم برسالة نصية)',
                border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: _reason.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _reason.text),
          child: const Text('رفض'),
        ),
      ],
    );
  }
}
