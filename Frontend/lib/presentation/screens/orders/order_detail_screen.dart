import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';

const _imgBase = 'http://localhost:5001';

final _orderDetailProvider = FutureProvider.autoDispose.family<OrderModel, String>(
  (ref, id) => ref.watch(orderRepositoryProvider).getOrder(id),
);

String _fmt(double v) => '\$${v.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '')}';

String _fmtDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(_orderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white))),
        data: (order) => _DetailBody(order: order),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final OrderModel order;
  const _DetailBody({required this.order});

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(order.status);

    return CustomScrollView(
      slivers: [
        // ── App Bar
        SliverAppBar(
          backgroundColor: AppColors.darkSurface,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
            onPressed: () => context.canPop() ? context.pop() : context.go('/orders'),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.orderNumber,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                _fmtDate(order.createdAt),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sc.withValues(alpha: 0.3)),
              ),
              child: Text(
                order.statusLabel,
                style: TextStyle(color: sc, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          pinned: true,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.darkBorder),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([

              // ── Status tracker
              _StatusStepper(status: order.status)
                  .animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 20),

              // ── Items
              _SectionLabel('ORDER ITEMS (${order.items.length})'),
              ...order.items.asMap().entries.map(
                (e) => _ItemTile(item: e.value, index: e.key),
              ),

              const SizedBox(height: 20),

              // ── Summary
              const _SectionLabel('PRICE SUMMARY'),
              _SummaryCard(order: order)
                  .animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 20),

              // ── Shipping address
              const _SectionLabel('DELIVERY ADDRESS'),
              _AddressCard(order: order)
                  .animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      );
}

// ── Status stepper ────────────────────────────────────────────────────────────

class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  static const _steps = ['pending', 'confirmed', 'processing', 'shipped', 'delivered'];
  static const _labels = ['Ordered', 'Confirmed', 'Processing', 'Shipped', 'Delivered'];
  static const _icons = [
    Icons.shopping_cart_outlined,
    Icons.check_circle_outline,
    Icons.settings_outlined,
    Icons.local_shipping_outlined,
    Icons.home_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == 'cancelled' || status == 'refunded';
    final idx = isCancelled ? -1 : _steps.indexOf(status).clamp(0, _steps.length - 1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancelled ? AppColors.error.withValues(alpha: 0.3) : AppColors.darkBorder,
        ),
      ),
      child: isCancelled
          ? Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status == 'refunded' ? 'Refunded' : 'Cancelled',
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const Text('This order has been cancelled', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ORDER PROGRESS',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(_steps.length * 2 - 1, (i) {
                    if (i.isOdd) {
                      final done = (i ~/ 2) < idx;
                      return Expanded(
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: done
                                ? const LinearGradient(colors: [AppColors.accent, AppColors.accentLight])
                                : null,
                            color: done ? null : AppColors.darkBorder,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      );
                    }
                    final si = i ~/ 2;
                    final done = si <= idx;
                    final current = si == idx;
                    return Column(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: current
                                ? AppColors.accent
                                : done
                                    ? AppColors.accent.withValues(alpha: 0.2)
                                    : Colors.transparent,
                            border: Border.all(
                              color: done ? AppColors.accent : AppColors.darkBorder,
                              width: current ? 2 : 1.5,
                            ),
                            boxShadow: current
                                ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 10)]
                                : null,
                          ),
                          child: Icon(
                            done && !current ? Icons.check_rounded : _icons[si],
                            size: 15,
                            color: done ? (current ? Colors.white : AppColors.accent) : AppColors.darkBorder,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _labels[si],
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                            color: done ? (current ? AppColors.accent : AppColors.darkTextSecondary) : AppColors.textMuted,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
    );
  }
}

// ── Item tile ─────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final OrderItem item;
  final int index;
  const _ItemTile({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final fullImg = item.productImage != null ? '$_imgBase${item.productImage}' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: fullImg != null
                ? Image.network(
                    fullImg,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _ImgPlaceholder(),
                  )
                : _ImgPlaceholder(),
          ),
          const SizedBox(width: 14),
          // Name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(item.unitPrice)} × ${item.quantity}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          // Total
          Text(
            _fmt(item.totalPrice),
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

class _ImgPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.darkBorder.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image_outlined, color: AppColors.textMuted, size: 22),
      );
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final OrderModel order;
  const _SummaryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          _SRow('Subtotal', _fmt(order.subtotal)),
          const SizedBox(height: 10),
          _SRow('Shipping', order.shippingCost == 0 ? 'Free' : _fmt(order.shippingCost),
              valueColor: AppColors.success),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.darkBorder, height: 1),
          ),
          _SRow('Total', _fmt(order.total),
              valueColor: AppColors.accent, bold: true, valueFontSize: 18),
        ],
      ),
    );
  }
}

class _SRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool bold;
  final double valueFontSize;
  const _SRow(this.label, this.value, {this.valueColor, this.bold = false, this.valueFontSize = 14});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: valueFontSize,
            ),
          ),
        ],
      );
}

// ── Address card ──────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final OrderModel order;
  const _AddressCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.location_on_outlined, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.shippingName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(order.shippingEmail, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ],
          ),
          if (order.shippingPhone != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(order.shippingPhone!, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: AppColors.darkBorder, height: 1),
          const SizedBox(height: 12),
          _addressLine(Icons.home_outlined, order.shippingAddressLine1),
          if (order.shippingAddressLine2 != null)
            _addressLine(null, order.shippingAddressLine2!),
          _addressLine(
            Icons.location_city_outlined,
            [
              order.shippingCity,
              if (order.shippingState != null) order.shippingState!,
              if (order.shippingPostalCode != null) order.shippingPostalCode!,
            ].join(', '),
          ),
          _addressLine(Icons.public_outlined, order.shippingCountry),
        ],
      ),
    );
  }

  Widget _addressLine(IconData? icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 22),
            Expanded(
              child: Text(text, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13, height: 1.4)),
            ),
          ],
        ),
      );
}