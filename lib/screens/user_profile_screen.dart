import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';

/// Context for the agent while chatting: who the sender is, their rides and
/// their wallet movements. Three tabs, each loads on its own.
class UserProfileScreen extends StatelessWidget {
  final int userId;
  final String userType;
  final String name;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userType,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F5),
        appBar: AppBar(
          title: Text(name, style: const TextStyle(fontSize: 17)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'الملف', icon: Icon(Icons.person_outline, size: 20)),
              Tab(text: 'الرحلات', icon: Icon(Icons.local_taxi_outlined, size: 20)),
              Tab(text: 'المحفظة', icon: Icon(Icons.account_balance_wallet_outlined, size: 20)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ProfileTab(userId: userId, userType: userType),
            _RidesTab(userId: userId, userType: userType),
            _WalletTab(userId: userId, userType: userType),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- helpers

final _dateTime = DateFormat('yyyy/MM/dd HH:mm');
final _dateOnly = DateFormat('yyyy/MM/dd');

String _fmtDateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d.toLocal());
String _fmtDate(DateTime? d) => d == null ? '—' : _dateOnly.format(d.toLocal());

String _money(double? v, [String? currency]) {
  if (v == null) return '—';
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  return currency == null || currency.isEmpty ? s : '$s $currency';
}

String _errText(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Loading / error / empty states shared by the three tabs.
class _StateView extends StatelessWidget {
  final Object? error;
  final bool loading;
  final bool empty;
  final String emptyText;
  final VoidCallback onRetry;
  const _StateView({
    required this.error,
    required this.loading,
    required this.empty,
    required this.emptyText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Color(0xFF667781)),
              const SizedBox(height: 8),
              Text(_errText(error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (empty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: Color(0xFF667781))),
      );
    }
    return const SizedBox.shrink();
  }
}

class _Card extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const _Card({this.title, required this.children});

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
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(title!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF075E54))),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// "label ........ value" row; hidden when the value is empty.
class _Row extends StatelessWidget {
  final String label;
  final String? value;
  final bool copyable;
  final Color? valueColor;
  const _Row(this.label, this.value, {this.copyable = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.isEmpty || v == '—') return const SizedBox.shrink();
    final text = Text(v,
        textAlign: TextAlign.left,
        style: TextStyle(
            fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF111B21)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Color(0xFF667781))),
          ),
          Expanded(
            child: copyable
                ? InkWell(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: v));
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم نسخ $v'), duration: const Duration(seconds: 1)));
                    },
                    child: text,
                  )
                : text,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ---------------------------------------------------------------- profile

class _ProfileTab extends StatefulWidget {
  final int userId;
  final String userType;
  const _ProfileTab({required this.userId, required this.userType});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab>
    with AutomaticKeepAliveClientMixin {
  UserProfile? _p;
  Object? _error;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

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
      final p = await Api.userProfile(widget.userId, widget.userType);
      if (!mounted) return;
      setState(() => _p = p);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = _p;
    if (p == null) {
      return _StateView(
          error: _error, loading: _loading, empty: false, emptyText: '', onRetry: _load);
    }
    final cur = p.currency;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Card(children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF128C7E),
                  child: Icon(p.isDriver ? Icons.local_taxi : Icons.person,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _Chip(p.isDriver ? 'سائق' : 'راكب', const Color(0xFF075E54)),
                        _Chip(p.status,
                            p.isBlocked ? Colors.red.shade700 : const Color(0xFF2E7D32)),
                        if (p.classification != null && p.classification!.isNotEmpty)
                          _Chip(p.classification!, Colors.indigo),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Row('رقم المستخدم', '${p.userId}', copyable: true),
            _Row('الهاتف', p.mobile, copyable: true),
            _Row('البريد', p.email, copyable: true),
            _Row('المدينة', p.city),
            if (p.isDriver) _Row('المكتب', p.partner),
          ]),
          _Card(title: 'المحفظة', children: [
            _Row('الرصيد', _money(p.walletBalance, cur),
                valueColor: p.walletBalance < 0 ? Colors.red.shade700 : const Color(0xFF2E7D32)),
            if (p.bonusBalance != null && p.bonusBalance != 0)
              _Row('رصيد البونص', _money(p.bonusBalance, cur)),
            if (p.bonusExpiresAt != null && (p.bonusBalance ?? 0) != 0)
              _Row('انتهاء البونص', _fmtDate(p.bonusExpiresAt)),
            if (p.points != null) _Row('النقاط الحالية', '${p.points}'),
            if (p.totalPoints != null) _Row('مجموع النقاط', '${p.totalPoints}'),
          ]),
          _Card(title: 'الرحلات', children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  _Stat('الكل', p.ridesTotal, const Color(0xFF075E54)),
                  _Stat('مكتملة', p.ridesCompleted, const Color(0xFF2E7D32)),
                  _Stat('ملغاة', p.ridesCancelled, Colors.red.shade700),
                ],
              ),
            ),
            _Row('آخر رحلة', _fmtDate(p.lastRideAt)),
            if (p.totalKm != null && p.totalKm! > 0)
              _Row('إجمالي المسافة', '${p.totalKm!.toStringAsFixed(0)} كم'),
          ]),
          if (p.isDriver)
            _Card(title: 'المركبة والرخصة', children: [
              _Row('رقم اللوحة', p.vehiclePlate, copyable: true),
              _Row('المركبة', p.vehicleDescription),
              _Row('النوع', p.vehicleType),
              _Row('رقم الهوية', p.nationalId, copyable: true),
              _Row('رقم الرخصة', p.licenseNumber),
              _Row('انتهاء الرخصة', _fmtDate(p.licenseExpiresAt),
                  valueColor: p.licenseExpiresAt != null &&
                          p.licenseExpiresAt!.isBefore(DateTime.now())
                      ? Colors.red.shade700
                      : null),
            ]),
          _Card(title: 'الحساب', children: [
            _Row('تاريخ الانضمام', _fmtDate(p.joinedAt)),
            if (p.isDriver) _Row('آخر نشاط', _fmtDateTime(p.lastActivityAt)),
            _Row('إصدار التطبيق', p.appVersion),
            _Row('الجهاز', p.device),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF667781))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- paged list

/// Shared "load first page, load more at the bottom, pull to refresh" logic.
abstract class _PagedTabState<T, W extends StatefulWidget> extends State<W>
    with AutomaticKeepAliveClientMixin {
  static const int pageSize = 30;

  final List<T> items = [];
  Object? error;
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  final scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  Future<List<T>> fetch(int skip, int take);
  Widget buildItem(BuildContext context, T item);
  String get emptyText;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.pixels >= scroll.position.maxScrollExtent - 200) {
        loadMore();
      }
    });
    reload();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await fetch(0, pageSize);
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(page);
        hasMore = page.length == pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    setState(() => loadingMore = true);
    try {
      final page = await fetch(items.length, pageSize);
      if (!mounted) return;
      setState(() {
        items.addAll(page);
        hasMore = page.length == pageSize;
      });
    } catch (_) {
      // Keep what we have; the user can scroll again to retry.
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (loading || error != null || items.isEmpty) {
      return _StateView(
        error: error,
        loading: loading,
        empty: items.isEmpty,
        emptyText: emptyText,
        onRetry: reload,
      );
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.builder(
        controller: scroll,
        padding: const EdgeInsets.all(12),
        itemCount: items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == items.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return buildItem(context, items[i]);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- rides

class _RidesTab extends StatefulWidget {
  final int userId;
  final String userType;
  const _RidesTab({required this.userId, required this.userType});

  @override
  State<_RidesTab> createState() => _RidesTabState();
}

class _RidesTabState extends _PagedTabState<UserRide, _RidesTab> {
  @override
  String get emptyText => 'لا توجد رحلات';

  @override
  Future<List<UserRide>> fetch(int skip, int take) =>
      Api.userRides(widget.userId, widget.userType, skip: skip, take: take);

  @override
  Widget buildItem(BuildContext context, UserRide r) {
    final isRider = widget.userType == 'rider';
    final statusColor = r.isCompleted
        ? const Color(0xFF2E7D32)
        : r.isCancelled
            ? Colors.red.shade700
            : Colors.orange.shade800;
    return _Card(children: [
      Row(
        children: [
          Text('#${r.id}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF075E54))),
          const SizedBox(width: 8),
          _Chip(r.status, statusColor),
          if (r.isScheduled) ...[
            const SizedBox(width: 6),
            _Chip('مجدولة', Colors.indigo),
          ],
          const Spacer(),
          Text(_fmtDateTime(r.createdAt),
              style: const TextStyle(fontSize: 12, color: Color(0xFF667781))),
        ],
      ),
      const SizedBox(height: 8),
      _Address(Icons.trip_origin, const Color(0xFF2E7D32), r.pickAddress),
      _Address(Icons.place_outlined, Colors.red.shade700, r.dropAddress),
      const SizedBox(height: 6),
      Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          if (r.amount != null)
            _Meta(Icons.payments_outlined, '${_money(r.amount, r.currency)} • ${r.paymentMethod}'),
          if (r.discount != null && r.discount! > 0)
            _Meta(Icons.discount_outlined, 'خصم ${_money(r.discount, r.currency)}'),
          if (r.distanceKm != null && r.distanceKm! > 0)
            _Meta(Icons.straighten, '${r.distanceKm!.toStringAsFixed(1)} كم'),
          if (r.duration != null && r.duration!.isNotEmpty)
            _Meta(Icons.timer_outlined, r.duration!),
          if (r.rating != null && r.rating! > 0)
            _Meta(Icons.star_outline, r.rating!.toStringAsFixed(1)),
        ],
      ),
      if (r.counterpartName != null && r.counterpartName!.isNotEmpty) ...[
        const SizedBox(height: 6),
        _Meta(isRider ? Icons.local_taxi_outlined : Icons.person_outline,
            '${isRider ? 'السائق' : 'الراكب'}: ${r.counterpartName}'
            '${r.counterpartMobile != null && r.counterpartMobile!.isNotEmpty ? ' • ${r.counterpartMobile}' : ''}'),
      ],
      if (r.isCancelled && r.cancelReason != null && r.cancelReason!.isNotEmpty) ...[
        const SizedBox(height: 6),
        _Meta(Icons.info_outline, 'سبب الإلغاء: ${r.cancelReason}', color: Colors.red.shade700),
      ],
      const SizedBox(height: 4),
    ]);
  }
}

class _Address extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? text;
  const _Address(this.icon, this.color, this.text);

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Meta(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF54656F);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: TextStyle(fontSize: 12.5, color: c))),
      ],
    );
  }
}

// ---------------------------------------------------------------- wallet

class _WalletTab extends StatefulWidget {
  final int userId;
  final String userType;
  const _WalletTab({required this.userId, required this.userType});

  @override
  State<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends _PagedTabState<WalletEntry, _WalletTab> {
  @override
  String get emptyText => 'لا توجد حركات على المحفظة';

  @override
  Future<List<WalletEntry>> fetch(int skip, int take) =>
      Api.userWallet(widget.userId, widget.userType, skip: skip, take: take);

  @override
  Widget buildItem(BuildContext context, WalletEntry t) {
    final color = t.isCredit ? const Color(0xFF2E7D32) : Colors.red.shade700;
    return _Card(children: [
      Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(t.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.type ?? (t.isCredit ? 'إيداع' : 'خصم'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(_fmtDateTime(t.createdAt),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF667781))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${t.isCredit ? '+' : ''}${_money(t.amount)}',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              if (t.balanceAfter != null)
                Text('الرصيد: ${_money(t.balanceAfter)}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF667781))),
            ],
          ),
        ],
      ),
      if (t.isBonus || t.rideId != null || (t.notes != null && t.notes!.isNotEmpty)) ...[
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            if (t.isBonus) const _Chip('بونص', Colors.indigo),
            if (t.rideId != null) _Meta(Icons.local_taxi_outlined, 'رحلة #${t.rideId}'),
            if (t.notes != null && t.notes!.isNotEmpty)
              _Meta(Icons.notes_outlined, t.notes!),
          ],
        ),
      ],
      const SizedBox(height: 4),
    ]);
  }
}
