import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/api_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _blue      = Color(0xFF0070D5);
const _menuBg    = Color(0xFF1A1A1A);
const _maxW      = 1200.0;
const _borderW   = 0.5;

final _priceFmt = NumberFormat('#,##0.##', 'en_US');
final _dateFmt  = DateFormat('MMM d, y');

String _fmtPrice(double v) => '\$${_priceFmt.format(v)}';
String _fmtDate(DateTime d) => _dateFmt.format(d);

Color _bg(bool dark)      => dark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F7);
Color _surface(bool dark) => dark ? const Color(0xFF111111) : Colors.white;
Color _border(bool dark)  => dark ? const Color(0xFF242424) : const Color(0xFFDEDEE2);
Color _txtPri(bool dark)  => dark ? const Color(0xFFF0F0F0) : const Color(0xFF111111);
Color _txtSub(bool dark)  => dark ? const Color(0xFF888888) : const Color(0xFF777777);

// ─── Status palette ───────────────────────────────────────────────────────────

Color _statusColor(String s) {
  switch (s) {
    case 'pending':    return const Color(0xFFD97706);
    case 'confirmed':
    case 'processing': return _blue;
    case 'shipped':    return const Color(0xFF8B5CF6);
    case 'delivered':  return const Color(0xFF10B981);
    case 'cancelled':
    case 'refunded':   return const Color(0xFFEF4444);
    default:           return Colors.grey;
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'pending':    return 'Pending';
    case 'confirmed':  return 'Confirmed';
    case 'processing': return 'Processing';
    case 'shipped':    return 'Shipped';
    case 'delivered':  return 'Delivered';
    case 'cancelled':  return 'Cancelled';
    case 'refunded':   return 'Refunded';
    default:           return s;
  }
}

const _statusFlow = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];

// ─── Provider ─────────────────────────────────────────────────────────────────

final _adminOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/orders', params: {'limit': 200});
  final data = (res.data as Map<String, dynamic>)['data'] as List;
  return data.map((o) => OrderModel.fromJson(o as Map<String, dynamic>)).toList();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersState();
}

class _AdminOrdersState extends ConsumerState<AdminOrdersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _filterStatus;
  String? _expandedId;
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase().trim()));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<OrderModel> _filter(List<OrderModel> all) => all.where((o) {
    final status = _filterStatus == null || o.status == _filterStatus;
    final search = _query.isEmpty ||
        o.orderNumber.toLowerCase().contains(_query) ||
        o.shippingName.toLowerCase().contains(_query) ||
        o.shippingEmail.toLowerCase().contains(_query);
    return status && search;
  }).toList();

  Future<void> _updateStatus(String id, String status) async {
    setState(() => _updating.add(id));
    try {
      await ref.read(apiServiceProvider).put('/admin/orders/$id/status', data: {'status': status});
      ref.invalidate(_adminOrdersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vw     = MediaQuery.of(context).size.width;
    final isWide = vw > 780;

    final ordersAsync = ref.watch(_adminOrdersProvider);
    final allOrders   = ordersAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: _bg(isDark),
      body: SafeArea(
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────────────
          _Header(
            isDark: isDark, isWide: isWide, vw: vw,
            total: allOrders.length,
            onBack: () => context.pop(),
            onRefresh: () => ref.invalidate(_adminOrdersProvider),
          ),

          // ── Search bar (pill-shaped) ────────────────────────────────────────
          _SearchRow(isDark: isDark, vw: vw, ctrl: _searchCtrl, query: _query),

          // ── Status filter tabs ───────────────────────────────────────────────
          _StatusFilterRow(
            isDark: isDark,
            allOrders: allOrders,
            selected: _filterStatus,
            onSelect: (s) => setState(() => _filterStatus = s),
          ),

          Divider(height: 1, thickness: _borderW, color: _border(isDark)),

          // ── Orders list ─────────────────────────────────────────────────────
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2)),
              error: (e, _) => _ErrorView(isDark: isDark, message: '$e', onRetry: () => ref.invalidate(_adminOrdersProvider)),
              data: (all) {
                final orders = _filter(all);

                if (orders.isEmpty) {
                  return _EmptyView(
                    isDark: isDark,
                    hasFilter: _query.isNotEmpty || _filterStatus != null,
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() => _filterStatus = null);
                    },
                  );
                }

                final hPad = vw > _maxW ? (vw - _maxW) / 2 : 16.0;

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 40),
                  itemCount: orders.length,
                  itemBuilder: (_, i) {
                    final o = orders[i];
                    return _OrderRow(
                      order: o,
                      isDark: isDark,
                      isWide: isWide,
                      isExpanded: _expandedId == o.id,
                      isUpdating: _updating.contains(o.id),
                      onTap: () => setState(() => _expandedId = _expandedId == o.id ? null : o.id),
                      onStatusChange: (s) => _updateStatus(o.id, s),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isDark, isWide;
  final double vw;
  final int total;
  final VoidCallback onBack, onRefresh;

  const _Header({required this.isDark, required this.isWide, required this.vw, required this.total, required this.onBack, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final hPad = vw > _maxW ? (vw - _maxW) / 2 : 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 12),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.arrow_back_ios_new_rounded, size: 11, color: _txtSub(isDark)),
            const SizedBox(width: 7),
            Text('DRONEHUB', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.5, color: _txtPri(isDark))),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                border: Border.all(color: _blue.withValues(alpha: 0.3), width: _borderW),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('ADMIN', style: TextStyle(color: _blue, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Text('/ Orders', style: TextStyle(fontSize: 13, color: _txtSub(isDark))),
        const Spacer(),
        if (total > 0)
          Text('$total orders total', style: TextStyle(fontSize: 12, color: _txtSub(isDark))),
        const SizedBox(width: 10),
        // Refresh button
        GestureDetector(
          onTap: onRefresh,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: _border(isDark), width: _borderW),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.refresh_rounded, size: 14, color: _txtSub(isDark)),
          ),
        ),
      ]),
    );
  }
}

// ─── Pill search bar ──────────────────────────────────────────────────────────

class _SearchRow extends StatelessWidget {
  final bool isDark;
  final double vw;
  final TextEditingController ctrl;
  final String query;

  const _SearchRow({required this.isDark, required this.vw, required this.ctrl, required this.query});

  @override
  Widget build(BuildContext context) {
    final hPad = vw > _maxW ? (vw - _maxW) / 2 : 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
      child: TextField(
        controller: ctrl,
        style: TextStyle(fontSize: 13, color: _txtPri(isDark)),
        decoration: InputDecoration(
          hintText: 'Search by order #, customer name, email...',
          hintStyle: TextStyle(fontSize: 13, color: _txtSub(isDark)),
          prefixIcon: Icon(Icons.search_rounded, size: 17, color: _txtSub(isDark)),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 14, color: _txtSub(isDark)),
                  onPressed: ctrl.clear,
                )
              : null,
          filled: true,
          fillColor: _surface(isDark),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: _borderW),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : _border(isDark),
              width: _borderW,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: _blue, width: 1),
          ),
        ),
      ),
    );
  }
}

// ─── Status filter tabs ───────────────────────────────────────────────────────

class _StatusFilterRow extends StatelessWidget {
  final bool isDark;
  final List<OrderModel> allOrders;
  final String? selected;
  final void Function(String?) onSelect;

  const _StatusFilterRow({required this.isDark, required this.allOrders, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final o in allOrders) { counts[o.status] = (counts[o.status] ?? 0) + 1; }

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        children: [
          _FilterPill(
            label: 'All',
            count: allOrders.length,
            color: _blue,
            isActive: selected == null,
            isDark: isDark,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 6),
          ..._statusFlow.map((s) {
            final c = counts[s] ?? 0;
            if (c == 0 && selected != s) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterPill(
                label: _statusLabel(s),
                count: c,
                color: _statusColor(s),
                isActive: selected == s,
                isDark: isDark,
                onTap: () => onSelect(selected == s ? null : s),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterPill extends StatefulWidget {
  final String label;
  final int count;
  final Color color;
  final bool isActive, isDark;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.count, required this.color, required this.isActive, required this.isDark, required this.onTap});

  @override
  State<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<_FilterPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final c = widget.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active ? c : (_hovered ? c.withValues(alpha: 0.1) : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? c : (_hovered ? c.withValues(alpha: 0.4) : _border(widget.isDark)),
              width: active ? 0 : _borderW,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : (_hovered ? c : _txtSub(widget.isDark)),
              ),
            ),
            if (widget.count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? Colors.white.withValues(alpha: 0.25) : c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: active ? Colors.white : c),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Order row ────────────────────────────────────────────────────────────────

class _OrderRow extends StatefulWidget {
  final OrderModel order;
  final bool isDark, isWide, isExpanded, isUpdating;
  final VoidCallback onTap;
  final void Function(String) onStatusChange;

  const _OrderRow({
    required this.order, required this.isDark, required this.isWide,
    required this.isExpanded, required this.isUpdating,
    required this.onTap, required this.onStatusChange,
  });

  @override
  State<_OrderRow> createState() => _OrderRowState();
}

class _OrderRowState extends State<_OrderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final o     = widget.order;
    final isDark = widget.isDark;
    final sColor = _statusColor(o.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hovered ? (isDark ? const Color(0xFF181818) : const Color(0xFFEBEBEE)) : _surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isExpanded ? sColor.withValues(alpha: 0.4) : _border(isDark),
            width: _borderW,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: [
          // ── Main row ──────────────────────────────────────────────────────
          MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: widget.isWide ? _WideRow(o: o, isDark: isDark, isUpdating: widget.isUpdating, onStatusChange: widget.onStatusChange) : _NarrowRow(o: o, isDark: isDark, isUpdating: widget.isUpdating, onStatusChange: widget.onStatusChange),
              ),
            ),
          ),

          // ── Expanded detail ────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: widget.isExpanded
                ? _OrderDetail(order: o, isDark: isDark)
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}

// Wide layout: all columns in one row
class _WideRow extends StatelessWidget {
  final OrderModel o;
  final bool isDark, isUpdating;
  final void Function(String) onStatusChange;
  const _WideRow({required this.o, required this.isDark, required this.isUpdating, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Order number
      SizedBox(
        width: 130,
        child: Text(o.orderNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _blue), overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(width: 12),

      // Customer
      Expanded(
        flex: 3,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(o.shippingName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _txtPri(isDark)), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(o.shippingEmail, style: TextStyle(fontSize: 11, color: _txtSub(isDark)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
      const SizedBox(width: 12),

      // Date
      SizedBox(
        width: 90,
        child: Text(_fmtDate(o.createdAt), style: TextStyle(fontSize: 11, color: _txtSub(isDark))),
      ),
      const SizedBox(width: 12),

      // Items
      SizedBox(
        width: 60,
        child: Row(children: [
          Icon(Icons.shopping_bag_outlined, size: 11, color: _txtSub(isDark)),
          const SizedBox(width: 4),
          Text('${o.items.length}', style: TextStyle(fontSize: 11, color: _txtSub(isDark))),
        ]),
      ),
      const SizedBox(width: 12),

      // Total
      SizedBox(
        width: 80,
        child: Text(_fmtPrice(o.total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _txtPri(isDark)), textAlign: TextAlign.right),
      ),
      const SizedBox(width: 14),

      // Status badge
      _StatusBadge(status: o.status),
      const SizedBox(width: 12),

      // Status changer
      if (isUpdating)
        const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: _blue, strokeWidth: 2))
      else
        _StatusChanger(currentStatus: o.status, isDark: isDark, onChange: onStatusChange),
    ]);
  }
}

// Narrow layout: stacked
class _NarrowRow extends StatelessWidget {
  final OrderModel o;
  final bool isDark, isUpdating;
  final void Function(String) onStatusChange;
  const _NarrowRow({required this.o, required this.isDark, required this.isUpdating, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(o.orderNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _blue))),
        Text(_fmtPrice(o.total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _txtPri(isDark))),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: Text(o.shippingName, style: TextStyle(fontSize: 12, color: _txtSub(isDark)), overflow: TextOverflow.ellipsis)),
        _StatusBadge(status: o.status),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Text('${o.items.length} item(s)  •  ${_fmtDate(o.createdAt)}', style: TextStyle(fontSize: 11, color: _txtSub(isDark))),
        const Spacer(),
        if (isUpdating)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _blue, strokeWidth: 2))
        else
          _StatusChanger(currentStatus: o.status, isDark: isDark, onChange: onStatusChange),
      ]),
    ]);
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
      child: Container(
        key: ValueKey(status),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.3), width: _borderW),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(_statusLabel(status), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ─── Status changer (custom PopupMenuButton) ──────────────────────────────────

class _StatusChanger extends StatefulWidget {
  final String currentStatus;
  final bool isDark;
  final void Function(String) onChange;
  const _StatusChanger({required this.currentStatus, required this.isDark, required this.onChange});

  @override
  State<_StatusChanger> createState() => _StatusChangerState();
}

class _StatusChangerState extends State<_StatusChanger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: _menuBg,
          elevation: 16,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: PopupMenuButton<String>(
          tooltip: 'Change status',
          onSelected: widget.onChange,
          offset: const Offset(0, 36),
          itemBuilder: (_) => _statusFlow.map((s) => PopupMenuItem<String>(
            value: s,
            padding: EdgeInsets.zero,
            child: _MenuOption(
              status: s,
              isSelected: s == widget.currentStatus,
            ),
          )).toList(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _hovered
                  ? _statusColor(widget.currentStatus).withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border(widget.isDark), width: _borderW),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _txtSub(widget.isDark))),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: _txtSub(widget.isDark)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MenuOption extends StatefulWidget {
  final String status;
  final bool isSelected;
  const _MenuOption({required this.status, required this.isSelected});

  @override
  State<_MenuOption> createState() => _MenuOptionState();
}

class _MenuOptionState extends State<_MenuOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(widget.status);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? c.withValues(alpha: 0.15) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusLabel(widget.status),
              style: TextStyle(
                color: widget.isSelected ? c : const Color(0xFFE0E0E0),
                fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (widget.isSelected)
            Icon(Icons.check_rounded, size: 14, color: c),
        ]),
      ),
    );
  }
}

// ─── Expanded order detail ─────────────────────────────────────────────────────

class _OrderDetail extends StatelessWidget {
  final OrderModel order;
  final bool isDark;
  const _OrderDetail({required this.order, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final borderColor = _border(isDark);
    final o = order;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: _borderW)),
        color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F8FA),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Shipping address
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.location_on_outlined, size: 13, color: _txtSub(isDark)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              [
                o.shippingAddressLine1,
                if (o.shippingAddressLine2 != null && o.shippingAddressLine2!.isNotEmpty) o.shippingAddressLine2!,
                '${o.shippingCity}${o.shippingState != null ? ', ${o.shippingState}' : ''}',
                o.shippingCountry,
              ].join(', '),
              style: TextStyle(fontSize: 12, color: _txtSub(isDark), height: 1.5),
            ),
          ),
          if (o.shippingPhone != null) Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.phone_outlined, size: 12, color: _txtSub(isDark)),
              const SizedBox(width: 4),
              Text(o.shippingPhone!, style: TextStyle(fontSize: 12, color: _txtSub(isDark))),
            ]),
          ),
        ]),

        const SizedBox(height: 14),

        // Items
        ...o.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Container(
              width: 4, height: 4,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: _txtSub(isDark), shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(item.productName, style: TextStyle(fontSize: 12, color: _txtPri(isDark))),
            ),
            Text('× ${item.quantity}', style: TextStyle(fontSize: 12, color: _txtSub(isDark))),
            const SizedBox(width: 16),
            SizedBox(
              width: 70,
              child: Text(_fmtPrice(item.totalPrice), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _txtPri(isDark)), textAlign: TextAlign.right),
            ),
          ]),
        )),

        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(height: _borderW, color: borderColor),
        ),

        // Totals
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _TotalLine(label: 'Subtotal', value: o.subtotal, isDark: isDark),
            _TotalLine(label: 'Shipping', value: o.shippingCost, isDark: isDark),
            _TotalLine(label: 'Tax', value: o.tax, isDark: isDark),
            const SizedBox(height: 4),
            Row(children: [
              Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _txtPri(isDark))),
              const SizedBox(width: 16),
              Text(_fmtPrice(o.total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _blue)),
            ]),
          ]),
        ]),
      ]),
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final double value;
  final bool isDark;
  const _TotalLine({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Text(label, style: TextStyle(fontSize: 11, color: _txtSub(isDark))),
      const SizedBox(width: 16),
      SizedBox(
        width: 70,
        child: Text(_fmtPrice(value), style: TextStyle(fontSize: 11, color: _txtSub(isDark)), textAlign: TextAlign.right),
      ),
    ]),
  );
}

// ─── States ───────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final bool isDark, hasFilter;
  final VoidCallback onClear;
  const _EmptyView({required this.isDark, required this.hasFilter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_outlined, size: 48, color: _txtSub(isDark)),
        const SizedBox(height: 14),
        Text(hasFilter ? 'No orders match your filter' : 'No orders yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _txtPri(isDark))),
        if (hasFilter) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(20)),
              child: const Text('Clear filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final bool isDark;
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.isDark, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 36),
      const SizedBox(height: 10),
      Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: onRetry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(20)),
          child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    ]));
  }
}
