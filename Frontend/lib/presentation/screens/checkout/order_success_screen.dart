import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../widgets/common/app_button.dart';

final _orderSuccessProvider = FutureProvider.autoDispose.family<OrderModel, String>(
  (ref, id) => ref.watch(orderRepositoryProvider).getOrder(id),
);

String _fmt(double v) =>
    '\$${v.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '')}';

class OrderSuccessScreen extends ConsumerWidget {
  final String orderId;
  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(_orderSuccessProvider(orderId));
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white))),
        data: (order) => _Body(order: order, orderId: orderId),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  final OrderModel order;
  final String orderId;
  const _Body({required this.order, required this.orderId});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _pA;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pA = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final firstName = order.shippingName.split(' ').first;

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.55),
          radius: 0.9,
          colors: [
            AppColors.accent.withValues(alpha: 0.14),
            AppColors.darkBg,
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - 64,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),

                // ── Animated icon
                AnimatedBuilder(
                  animation: _pA,
                  builder: (_, __) => SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer pulse ring
                        Container(
                          width: 150 + _pA.value * 10,
                          height: 150 + _pA.value * 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.15 * (1 - _pA.value)),
                              width: 2,
                            ),
                          ),
                        ),
                        // Middle ring
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.08 + _pA.value * 0.04),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Core
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.45),
                                blurRadius: 28 + _pA.value * 8,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 650.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: 36),

                // ── Title
                const Text(
                  'Order Placed!',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.5,
                    height: 1,
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),

                const SizedBox(height: 12),

                Text(
                  'Thank you, $firstName! Your order is confirmed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.darkTextSecondary,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 6),

                Text(
                  'A receipt + PDF invoice will be emailed to\n${order.shippingEmail}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 450.ms),

                const SizedBox(height: 24),

                // ── Order number badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.18),
                        AppColors.accent.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 14, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

                const SizedBox(height: 28),

                // ── Summary card
                _SummaryCard(order: order).animate().fadeIn(delay: 600.ms).slideY(begin: 0.15, end: 0),

                const SizedBox(height: 20),

                // ── Status tracker
                _StatusTracker(status: order.status).animate().fadeIn(delay: 700.ms),

                const SizedBox(height: 36),

                // ── CTAs
                AppButton(
                  label: 'View Order Details',
                  icon: Icons.receipt_long_outlined,
                  onPressed: () => context.go('/orders/${widget.orderId}'),
                ).animate().fadeIn(delay: 800.ms),

                const SizedBox(height: 12),

                AppButton(
                  label: 'Continue Shopping',
                  isOutlined: true,
                  icon: Icons.shopping_bag_outlined,
                  onPressed: () => context.go('/'),
                ).animate().fadeIn(delay: 850.ms),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final OrderModel order;
  const _SummaryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          _Row(label: 'Items', value: '${order.items.length} item(s)'),
          const SizedBox(height: 12),
          const _Row(label: 'Shipping', value: 'Free', valueColor: AppColors.success),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.darkBorder, height: 1),
          ),
          _Row(
            label: 'Total',
            value: _fmt(order.total),
            valueColor: AppColors.accent,
            bold: true,
            valueFontSize: 18,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool bold;
  final double valueFontSize;
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
    this.valueFontSize = 14,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
          ),
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

// ── Status tracker ────────────────────────────────────────────────────────────

class _StatusTracker extends StatelessWidget {
  final String status;
  const _StatusTracker({required this.status});

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
    final idx = _steps.indexOf(status).clamp(0, _steps.length - 1);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER PROGRESS',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
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
                          ? const LinearGradient(
                              colors: [AppColors.accent, AppColors.accentLight],
                            )
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? (current
                              ? AppColors.accent
                              : AppColors.accent.withValues(alpha: 0.2))
                          : AppColors.darkBorder.withValues(alpha: 0.3),
                      border: Border.all(
                        color: done ? AppColors.accent : AppColors.darkBorder,
                        width: current ? 2 : 1.5,
                      ),
                      boxShadow: current
                          ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 8)]
                          : null,
                    ),
                    child: Icon(
                      _icons[si],
                      size: 14,
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