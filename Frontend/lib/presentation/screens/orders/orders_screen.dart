import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';

const _imgBase = 'http://localhost:5001';

final _myOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>(
  (ref) => ref.watch(orderRepositoryProvider).getMyOrders(),
);

String _fmtDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String _fmtPrice(double v) =>
    '\$${v.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '')}';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_myOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white))),
        data: (orders) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Orders',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        if (orders.isNotEmpty)
                          Text(
                            '${orders.length} order${orders.length == 1 ? '' : 's'}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (orders.isNotEmpty)
                      _StatBadge(
                        label: _pendingCount(orders) > 0 ? '${_pendingCount(orders)} pending' : 'All clear',
                        color: _pendingCount(orders) > 0 ? AppColors.warning : AppColors.success,
                      ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 20),

            // ── List / Empty
            Expanded(
              child: orders.isEmpty
                  ? _EmptyState()
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(_myOrdersProvider),
                      color: AppColors.accent,
                      backgroundColor: AppColors.darkCard,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: orders.length,
                        itemBuilder: (_, i) => _OrderCard(order: orders[i], index: i),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int _pendingCount(List<OrderModel> orders) =>
      orders.where((o) => o.status == 'pending' || o.status == 'confirmed' || o.status == 'processing').length;
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.darkCard,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textMuted),
          ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
          const SizedBox(height: 20),
          const Text(
            'No orders yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          const Text(
            'Your orders will appear here',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.go('/products'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Start Shopping',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final int index;
  const _OrderCard({required this.order, required this.index});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final thumb = order.items.isNotEmpty ? order.items.first.productImage : null;
    final fullThumb = thumb != null ? '$_imgBase$thumb' : null;

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Status accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Thumbnail
                      if (fullThumb != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            fullThumb,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _PlaceholderThumb(),
                          ),
                        )
                      else
                        _PlaceholderThumb(),

                      const SizedBox(width: 14),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.orderNumber,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _fmtDate(order.createdAt),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      // Right side
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              order.statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _fmtPrice(order.total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          .animate(delay: Duration(milliseconds: index * 60))
          .fadeIn(duration: 350.ms)
          .slideX(begin: 0.05, end: 0),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed':
      case 'processing':
        return AppColors.info;
      case 'shipped':
        return AppColors.warning;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
      case 'refunded':
        return AppColors.error;
      default:
        return AppColors.darkTextSecondary;
    }
  }
}

class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.darkBorder.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image_outlined, color: AppColors.textMuted, size: 22),
      );
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}