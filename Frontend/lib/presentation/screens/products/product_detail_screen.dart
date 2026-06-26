import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_shimmer.dart';

final _productDetailProvider =
    FutureProvider.autoDispose.family<ProductModel, String>((ref, slug) {
  return ref.watch(productRepositoryProvider).getProductBySlug(slug);
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  final bool autoAdd;
  const ProductDetailScreen({super.key, required this.slug, this.autoAdd = false});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final _pageCtrl = PageController();
  int _imgIdx = 0;
  int _quantity = 1;
  bool _addingToCart = false;
  bool _didAutoAdd = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productAsync = ref.watch(_productDetailProvider(widget.slug));

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F8F8),
      body: productAsync.when(
        loading: () => _Skeleton(isDark: isDark),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load product', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.pop(), child: const Text('Go Back')),
            ],
          ),
        ),
        data: (p) {
          // Auto-add to cart if user was redirected back after auth
          if (widget.autoAdd && !_didAutoAdd && ref.read(authProvider).isAuthenticated) {
            _didAutoAdd = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _addToCart(p));
          }
          return _ProductLayout(
            product: p,
            pageCtrl: _pageCtrl,
            imgIdx: _imgIdx,
            quantity: _quantity,
            addingToCart: _addingToCart,
            isDark: isDark,
            onPageChanged: (i) => setState(() => _imgIdx = i),
            onQtyDec: () { if (_quantity > 1) setState(() => _quantity--); },
            onQtyInc: () { if (_quantity < p.stock) setState(() => _quantity++); },
            onAddToCart: () => _addToCart(p),
            onImageTap: (i) => _openFullscreen(p.allImageUrls, i),
          );
        },
      ),
    );
  }

  Future<void> _addToCart(ProductModel product) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      context.push('/login?redirect=${Uri.encodeComponent('/products/${product.slug}?autoAdd=true')}');
      return;
    }
    setState(() => _addingToCart = true);
    try {
      await ref.read(cartProvider.notifier).addItem(product.id, quantity: _quantity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} added to cart'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  void _openFullscreen(List<String> urls, int startIdx) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _FullscreenGallery(urls: urls, initialIndex: startIdx),
    );
  }
}

// ─── Full layout (desktop split / mobile stack) ───────────────────────────────

class _ProductLayout extends StatelessWidget {
  final ProductModel product;
  final PageController pageCtrl;
  final int imgIdx, quantity;
  final bool addingToCart, isDark;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onQtyDec, onQtyInc, onAddToCart;
  final ValueChanged<int> onImageTap;

  const _ProductLayout({
    required this.product, required this.pageCtrl, required this.imgIdx,
    required this.quantity, required this.addingToCart, required this.isDark,
    required this.onPageChanged, required this.onQtyDec, required this.onQtyInc,
    required this.onAddToCart, required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // Content
        w > 800
            ? Row(
                children: [
                  // Left: sticky image gallery
                  SizedBox(
                    width: w * 0.48,
                    child: _ImageGallery(
                      product: product,
                      pageCtrl: pageCtrl,
                      imgIdx: imgIdx,
                      isDark: isDark,
                      onPageChanged: onPageChanged,
                      onTap: onImageTap,
                    ),
                  ),
                  // Right: scrollable info
                  Expanded(
                    child: _InfoPanel(
                      product: product,
                      quantity: quantity,
                      addingToCart: addingToCart,
                      isDark: isDark,
                      onQtyDec: onQtyDec,
                      onQtyInc: onQtyInc,
                      onAddToCart: onAddToCart,
                      topPadding: MediaQuery.of(context).padding.top + 72,
                    ),
                  ),
                ],
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 320,
                      child: _ImageGallery(
                        product: product,
                        pageCtrl: pageCtrl,
                        imgIdx: imgIdx,
                        isDark: isDark,
                        onPageChanged: onPageChanged,
                        onTap: onImageTap,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _InfoPanel(
                      product: product,
                      quantity: quantity,
                      addingToCart: addingToCart,
                      isDark: isDark,
                      onQtyDec: onQtyDec,
                      onQtyInc: onQtyInc,
                      onAddToCart: onAddToCart,
                      topPadding: 24,
                    ),
                  ),
                ],
              ),

        // Floating back button
        Positioned(
          top: 0, left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _OverlayBtn(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
                isDark: isDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Floating overlay buttons ─────────────────────────────────────────────────

class _OverlayBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  const _OverlayBtn({required this.icon, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
        ),
        child: Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black),
      ),
    );
  }
}

// ─── Image gallery ────────────────────────────────────────────────────────────

class _ImageGallery extends StatelessWidget {
  final ProductModel product;
  final PageController pageCtrl;
  final int imgIdx;
  final bool isDark;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onTap;

  const _ImageGallery({
    required this.product, required this.pageCtrl, required this.imgIdx,
    required this.isDark, required this.onPageChanged, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final urls = product.allImageUrls;
    final bg = isDark ? Colors.black : const Color(0xFFF5F5F7);

    return Container(
      color: bg,
      child: Stack(
        children: [
          // Pages
          urls.isEmpty
              ? Center(child: Icon(Icons.flight, size: 80, color: isDark ? Colors.white12 : Colors.black12))
              : PageView.builder(
                  controller: pageCtrl,
                  itemCount: urls.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (_, i) => MouseRegion(
                    cursor: SystemMouseCursors.zoomIn,
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      child: Image.network(
                        urls[i],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined,
                            size: 60, color: isDark ? Colors.white24 : Colors.black12),
                      ),
                    ),
                  ),
                ),

          // Dots — always visible with shadow
          if (urls.length > 1)
            Positioned(
              bottom: 16, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (i) {
                  final active = i == imgIdx;
                  return AnimatedContainer(
                    duration: 200.ms,
                    width: active ? 20 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.25), width: 0.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4)],
                    ),
                  );
                }),
              ),
            ),

          // Thumbnail strip at bottom
          if (urls.length > 1)
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: urls.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () {
                      pageCtrl.animateToPage(i, duration: 250.ms, curve: Curves.easeOut);
                    },
                    child: AnimatedContainer(
                      duration: 150.ms,
                      width: 48, height: 48,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: i == imgIdx ? AppColors.accent : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.network(urls[i], fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: isDark ? const Color(0xFF222) : Colors.grey.shade200)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Info panel ───────────────────────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  final ProductModel product;
  final int quantity;
  final bool addingToCart, isDark;
  final VoidCallback onQtyDec, onQtyInc, onAddToCart;
  final double topPadding;

  const _InfoPanel({
    required this.product, required this.quantity, required this.addingToCart,
    required this.isDark, required this.onQtyDec, required this.onQtyInc,
    required this.onAddToCart, required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(28, topPadding, 28, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand + Category row
          Row(children: [
            if (product.brand != null)
              Text(product.brand!.toUpperCase(),
                  style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5))
                  .animate().fadeIn(delay: 50.ms),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                product.category.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: sub),
              ),
            ),
          ]).animate().fadeIn(delay: 80.ms),

          const SizedBox(height: 14),

          // Name
          Text(product.name,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: fg, height: 1.2))
              .animate().fadeIn(delay: 120.ms),

          const SizedBox(height: 20),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.formatPrice(product.price),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.accent),
              ),
              if (product.hasDiscount) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    product.formatPrice(product.comparePrice!),
                    style: TextStyle(fontSize: 18, color: sub, decoration: TextDecoration.lineThrough),
                  ),
                ),
              ],
            ],
          ).animate().fadeIn(delay: 160.ms),

          const SizedBox(height: 12),

          // Stock badge
          _StockBadge(stock: product.stock).animate().fadeIn(delay: 180.ms),

          const SizedBox(height: 24),

          // Divider
          Divider(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
          const SizedBox(height: 20),

          // Short description
          if (product.shortDescription != null && product.shortDescription!.isNotEmpty) ...[
            Text(product.shortDescription!,
                style: TextStyle(fontSize: 15, color: fg, fontWeight: FontWeight.w500, height: 1.6))
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 16),
          ],

          // Full description
          Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(product.description,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54, height: 1.7))
              .animate().fadeIn(delay: 240.ms),

          // Specs
          if (product.specifications != null && product.specifications!.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Specifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            _SpecsTable(specs: product.specifications!, isDark: isDark),
          ],

          const SizedBox(height: 36),

          // Quantity
          if (product.inStock) ...[
            Text('Quantity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Row(children: [
              _QtyBtn(icon: Icons.remove, onTap: onQtyDec, isDark: isDark),
              const SizedBox(width: 20),
              Text('$quantity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
              const SizedBox(width: 20),
              _QtyBtn(icon: Icons.add, onTap: onQtyInc, isDark: isDark),
              const Spacer(),
              Text('${product.stock} in stock', style: TextStyle(fontSize: 12, color: sub)),
            ]),
            const SizedBox(height: 24),
          ],

          // Add to cart button
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: GestureDetector(
              onTap: addingToCart ? null : onAddToCart,
              child: AnimatedContainer(
                duration: 150.ms,
                height: 52,
                decoration: BoxDecoration(
                  color: product.inStock
                      ? (addingToCart ? AppColors.accent.withValues(alpha: 0.7) : AppColors.accent)
                      : (isDark ? const Color(0xFF222) : const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: addingToCart
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              product.inStock ? Icons.shopping_cart_outlined : Icons.block_outlined,
                              color: product.inStock ? Colors.white : sub,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              product.inStock ? 'Add to Cart' : 'Out of Stock',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: product.inStock ? Colors.white : sub,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}

// ─── Fullscreen gallery dialog ────────────────────────────────────────────────

class _FullscreenGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _FullscreenGallery({required this.urls, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _ctrl;
  late int _idx;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex;
    _ctrl = PageController(initialPage: _idx);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image viewer
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: Image.network(
                widget.urls[i],
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),

          // Counter
          Positioned(
            top: MediaQuery.of(context).padding.top + 18,
            left: 0, right: 0,
            child: Center(
              child: Text(
                '${_idx + 1} / ${widget.urls.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Prev/Next arrows
          if (widget.urls.length > 1) ...[
            Positioned(
              left: 12, top: 0, bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _ctrl.previousPage(duration: 250.ms, curve: Curves.easeOut),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12, top: 0, bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _ctrl.nextPage(duration: 250.ms, curve: Curves.easeOut),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
          ],

          // Dots at bottom
          if (widget.urls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.urls.length, (i) => AnimatedContainer(
                  duration: 200.ms,
                  width: i == _idx ? 20 : 7, height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _idx ? AppColors.accent : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  final int stock;
  const _StockBadge({required this.stock});

  @override
  Widget build(BuildContext context) {
    final ok = stock > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (ok ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ok ? 'In Stock' : 'Out of Stock',
        style: TextStyle(color: ok ? AppColors.success : AppColors.error, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  const _QtyBtn({required this.icon, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }
}

class _SpecsTable extends StatelessWidget {
  final Map<String, dynamic> specs;
  final bool isDark;
  const _SpecsTable({required this.specs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final entries = specs.entries.toList();
    final border = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: entries.asMap().entries.map((e) {
          final isLast = e.key == entries.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: border)),
            ),
            child: Row(children: [
              Expanded(child: Text(e.value.key, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white70 : Colors.black54))),
              Expanded(child: Text('${e.value.value}', style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black))),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final bool isDark;
  const _Skeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const LoadingShimmer(height: 360, radius: 0),
      const SizedBox(height: 24),
      ...List.generate(4, (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: LoadingShimmer(height: 18, width: MediaQuery.of(context).size.width * 0.6),
      )),
    ]);
  }
}