import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cart_model.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common/loading_shimmer.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F8F8),
      body: Column(
        children: [
          // ── Custom header ──────────────────────────────────────────────────
          _CartHeader(isDark: isDark, canPop: canPop, cartAsync: cartAsync),

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: cartAsync.when(
              loading: () => _buildSkeleton(),
              error: (e, _) => Center(
                child: Text('Error: $e', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
              ),
              data: (cart) => cart.isEmpty
                  ? _EmptyCart(isDark: isDark)
                  : _CartLayout(cart: cart, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      itemCount: 3,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LoadingShimmer(height: 100, width: double.infinity),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _CartHeader extends StatelessWidget {
  final bool isDark, canPop;
  final AsyncValue<CartModel> cartAsync;
  const _CartHeader({required this.isDark, required this.canPop, required this.cartAsync});

  @override
  Widget build(BuildContext context) {
    final itemCount = cartAsync.whenOrNull(data: (c) => c.itemCount) ?? 0;

    return Container(
      color: isDark ? Colors.black : const Color(0xFFF8F8F8),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16),
      child: Row(
        children: [
          if (canPop)
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 38, height: 38,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_back_rounded, size: 18, color: isDark ? Colors.white : Colors.black),
              ),
            ),
          Text(
            'Cart',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
          ),
          if (itemCount > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
              child: Text('$itemCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Desktop split / mobile stack ────────────────────────────────────────────

class _CartLayout extends ConsumerWidget {
  final CartModel cart;
  final bool isDark;
  const _CartLayout({required this.cart, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.of(context).size.width;
    final summary = _SummaryData(
      subtotal: cart.subtotal,
      total: cart.subtotal,
      count: cart.itemCount,
    );

    if (w > 860) {
      // Desktop: left list, right sticky summary
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _ItemsList(items: cart.items, isDark: isDark),
          ),
          SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: _OrderSummary(data: summary, isDark: isDark),
            ),
          ),
        ],
      );
    }

    // Mobile: stacked
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: EdgeInsets.fromLTRB(20, i == 0 ? 12 : 0, 20, 12),
              child: _CartItemCard(item: cart.items[i], isDark: isDark, index: i),
            ),
            childCount: cart.items.length,
          ),
        ),
        SliverToBoxAdapter(child: _OrderSummary(data: summary, isDark: isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ─── Items list (desktop left column) ────────────────────────────────────────

class _ItemsList extends StatelessWidget {
  final List<CartItem> items;
  final bool isDark;
  const _ItemsList({required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 24),
      itemCount: items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _CartItemCard(item: items[i], isDark: isDark, index: i),
      ),
    );
  }
}

// ─── Single cart item card ────────────────────────────────────────────────────

class _CartItemCard extends ConsumerStatefulWidget {
  final CartItem item;
  final bool isDark;
  final int index;
  const _CartItemCard({required this.item, required this.isDark, required this.index});

  @override
  ConsumerState<_CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends ConsumerState<_CartItemCard> {
  bool _updating = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final imgUrl = item.product.fullPrimaryImageUrl;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
      ),
      onDismissed: (_) => ref.read(cartProvider.notifier).removeItem(item.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0E0E0E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF222) : const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            // Product image with ambient blur
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80, height: 80,
                child: imgUrl.isEmpty
                    ? Container(
                        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F7),
                        child: Icon(Icons.airplanemode_active_rounded, color: isDark ? Colors.white24 : Colors.black12, size: 32),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Transform.scale(
                              scale: 1.4,
                              child: Image.network(imgUrl, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F7))),
                            ),
                          ),
                          Image.network(imgUrl, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.airplanemode_active_rounded, size: 32, color: isDark ? Colors.white24 : Colors.black12)),
                        ],
                      ),
              ),
            ),

            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.product.category.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Qty control
                      _QtyControl(
                        qty: item.quantity,
                        updating: _updating,
                        onDec: () => _update(item.quantity - 1, item),
                        onInc: () => _update(item.quantity + 1, item),
                        isDark: isDark,
                      ),
                      const Spacer(),
                      // Item total
                      Text(
                        item.product.formatPrice(item.itemTotal),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Delete button
            GestureDetector(
              onTap: () => ref.read(cartProvider.notifier).removeItem(item.id),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
              ),
            ),
          ],
        ),
      ).animate(delay: Duration(milliseconds: widget.index * 50)).fadeIn().slideX(begin: -0.06),
    );
  }

  Future<void> _update(int qty, CartItem item) async {
    if (qty < 1) {
      await ref.read(cartProvider.notifier).removeItem(item.id);
      return;
    }
    setState(() => _updating = true);
    try {
      await ref.read(cartProvider.notifier).updateItem(item.id, qty);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }
}

// ─── Quantity control ─────────────────────────────────────────────────────────

class _QtyControl extends StatelessWidget {
  final int qty;
  final bool updating, isDark;
  final VoidCallback onDec, onInc;
  const _QtyControl({required this.qty, required this.updating, required this.isDark, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(icon: Icons.remove, onTap: updating ? null : onDec, isDark: isDark),
          SizedBox(
            width: 32,
            child: Center(
              child: updating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : Text('$qty', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
            ),
          ),
          _Btn(icon: Icons.add, onTap: updating ? null : onInc, isDark: isDark),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;
  const _Btn({required this.icon, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        child: Icon(icon, size: 14, color: onTap == null ? (isDark ? Colors.white24 : Colors.black26) : (isDark ? Colors.white70 : Colors.black54)),
      ),
    );
  }
}

// ─── Order summary ────────────────────────────────────────────────────────────

class _SummaryData {
  final double subtotal, total;
  final int count;
  const _SummaryData({required this.subtotal, required this.total, required this.count});
}

class _OrderSummary extends StatelessWidget {
  final _SummaryData data;
  final bool isDark;
  const _OrderSummary({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E0E0E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF222) : const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 20),

          _SummaryRow('Subtotal (${data.count} ${data.count == 1 ? 'item' : 'items'})', _fmtPrice(data.subtotal), isDark: isDark),
          const SizedBox(height: 10),
          _SummaryRow('Shipping', 'Free', isDark: isDark, valueColor: AppColors.success),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
          ),

          Row(
            children: [
              Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
              const Spacer(),
              Text(_fmtPrice(data.total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.accent)),
            ],
          ),

          const SizedBox(height: 20),

          // Checkout button
          GestureDetector(
            onTap: () => context.push('/checkout'),
            child: Container(
              height: 50,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Proceed to Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Continue shopping
          GestureDetector(
            onTap: () => context.push('/products'),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF333) : const Color(0xFFDDD)),
              ),
              child: Center(
                child: Text('Continue Shopping', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sub)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a price exactly as stored — strips trailing zeros, keeps all significant decimals.
String _fmtPrice(double v) => '\$${v.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '')}';

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool isDark;
  final Color? valueColor;
  const _SummaryRow(this.label, this.value, {required this.isDark, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? (isDark ? Colors.white : Colors.black))),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  final bool isDark;
  const _EmptyCart({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 72, color: isDark ? Colors.white12 : Colors.black12)
              .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text('Your cart is empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black))
              .animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 8),
          Text('Start adding some drone parts',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38))
              .animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => context.push('/products'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
              child: const Text('Shop Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
        ],
      ),
    );
  }
}