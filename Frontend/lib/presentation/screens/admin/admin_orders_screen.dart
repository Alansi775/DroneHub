import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/api_service.dart';

final _adminOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/orders', params: {'limit': 100});
  final data = (res.data as Map<String, dynamic>)['data'] as List;
  return data.map((o) => OrderModel.fromJson(o as Map<String, dynamic>)).toList();
});

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_adminOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Orders'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (orders) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_adminOrdersProvider),
          child: orders.isEmpty
              ? const Center(child: Text('No orders yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _AdminOrderTile(
                    order: orders[i],
                    onRefresh: () => ref.invalidate(_adminOrdersProvider),
                  ),
                ),
        ),
      ),
    );
  }
}

class _AdminOrderTile extends ConsumerWidget {
  final OrderModel order;
  final VoidCallback onRefresh;
  const _AdminOrderTile({required this.order, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent)),
              Text('\$${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(order.shippingName, style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text('${order.items.length} item(s)', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatusChip(status: order.status, color: statusColor),
              const Spacer(),
              _StatusDropdown(orderId: order.id, currentStatus: order.status, onChanged: () async {
                onRefresh();
              }, ref: ref),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': case 'processing': return AppColors.info;
      case 'shipped': return AppColors.warning;
      case 'delivered': return AppColors.success;
      case 'cancelled': case 'refunded': return AppColors.error;
      default: return Colors.grey;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatusDropdown extends StatefulWidget {
  final String orderId;
  final String currentStatus;
  final VoidCallback onChanged;
  final WidgetRef ref;
  const _StatusDropdown({required this.orderId, required this.currentStatus, required this.onChanged, required this.ref});

  @override
  State<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends State<_StatusDropdown> {
  late String _selected;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentStatus;
  }

  @override
  Widget build(BuildContext context) {
    return _updating
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : DropdownButton<String>(
            value: _selected,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
              DropdownMenuItem(value: 'processing', child: Text('Processing')),
              DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
              DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (v) async {
              if (v == null || v == _selected) return;
              setState(() { _selected = v; _updating = true; });
              try {
                await widget.ref.read(apiServiceProvider).put('/admin/orders/${widget.orderId}/status', data: {'status': v});
                widget.onChanged();
              } catch (_) {
                setState(() => _selected = widget.currentStatus);
              } finally {
                if (mounted) setState(() => _updating = false);
              }
            },
          );
  }
}
