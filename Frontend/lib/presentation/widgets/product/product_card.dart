import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final int index;
  const ProductCard({super.key, required this.product, required this.index});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.product;
    final outOfStock = !p.inStock;
    final imgUrl = p.fullPrimaryImageUrl;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/products/${p.slug}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          transform: _hovered && !outOfStock
              ? (Matrix4.identity()..translate(0, -8, 0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: outOfStock
                  ? AppColors.error.withValues(alpha: 0.35)
                  : _hovered
                      ? AppColors.accent.withValues(alpha: 0.5)
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.5,
            ),
            boxShadow: _hovered && !outOfStock
                ? [BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8))]
                : [],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image area with ambient blur background ──────────────
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(19),
                        topRight: Radius.circular(19),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Ambient blur — no scrim, exact image colors
                          if (imgUrl.isNotEmpty)
                            ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                              child: Transform.scale(
                                scale: 1.4,
                                child: Image.network(
                                  imgUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: isDark ? const Color(0xFF111) : const Color(0xFFF5F5F7),
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(color: isDark ? const Color(0xFF111) : const Color(0xFFF5F5F7)),

                          // Actual image — contain, no padding, flush to edges
                          if (imgUrl.isNotEmpty)
                            Image.network(
                              imgUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.airplanemode_active_rounded,
                                color: isDark ? Colors.white24 : Colors.black12,
                                size: 52,
                              ),
                            )
                          else
                            Icon(
                              Icons.airplanemode_active_rounded,
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              size: 52,
                            ),

                          // Discount badge
                          if (p.hasDiscount)
                            Positioned(
                              top: 8, left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '-${p.discountPercent.toInt()}%',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),

                          // Add to cart hover button
                          if (_hovered && !outOfStock)
                            Positioned(
                              bottom: 8, right: 8,
                              child: AnimatedOpacity(
                                opacity: _hovered ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Info area ──────────────────────────────────────────────
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category
                          Text(
                            p.category.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Name
                          Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                              height: 1.25,
                            ),
                          ),
                          if (p.shortDescription != null && p.shortDescription!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Expanded(
                              child: Text(
                                p.shortDescription!,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          const SizedBox(height: 8),
                          // Price row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                p.formatPrice(p.price),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (p.hasDiscount) ...[
                                const SizedBox(width: 6),
                                Text(
                                  p.formatPrice(p.comparePrice!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white30 : Colors.black26,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: _hovered
                                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                                    : const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: _hovered ? AppColors.accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _hovered ? AppColors.accent : (isDark ? Colors.white24 : Colors.black12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_hovered)
                                      Text(
                                        'Buy',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                      ),
                                    if (_hovered) const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: _hovered ? Colors.white : (isDark ? Colors.white30 : Colors.black26),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Out of stock overlay
              if (outOfStock)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}