import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/api_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class _AdminCategory {
  final String id, name, slug;
  final List<String> previewImages;
  final int productCount;
  const _AdminCategory({required this.id, required this.name, required this.slug, required this.previewImages, required this.productCount});
  factory _AdminCategory.fromJson(Map<String, dynamic> j) => _AdminCategory(
    id: j['id'] as String, name: j['name'] as String, slug: j['slug'] as String,
    previewImages: List<String>.from(j['previewImages'] as List? ?? []),
    productCount: j['productCount'] as int? ?? 0,
  );
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _adminCatsProvider = FutureProvider.autoDispose<List<_AdminCategory>>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/categories');
  final data = (res.data as Map<String, dynamic>)['data'] as List;
  return data.map((c) => _AdminCategory.fromJson(c as Map<String, dynamic>)).toList();
});

final _adminProductsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/products', params: {'limit': '200'});
  final data = (res.data as Map<String, dynamic>)['data'] as List;
  return data.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
});

final _pendingCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/pending-orders-count');
  return ((res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>)['count'] as int? ?? 0;
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final catCols = w > 1400 ? 5 : w > 1100 ? 4 : w > 800 ? 3 : 2;
    final prodCols = w > 1400 ? 6 : w > 1100 ? 5 : w > 800 ? 4 : 3;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _AdminHeader(isDark: isDark, ref: ref)),

          // ── Action buttons ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  _ActionBtn(
                    label: '+ Add Category',
                    filled: false,
                    isDark: isDark,
                    onTap: () => _showAddCategoryDialog(context, ref, isDark),
                  ),
                  const SizedBox(width: 12),
                  _ActionBtn(
                    label: '+ Add Product',
                    filled: true,
                    isDark: isDark,
                    onTap: () => context.push('/admin/products/add').then((_) {
                      ref.invalidate(_adminProductsProvider);
                      ref.invalidate(_adminCatsProvider);
                    }),
                  ),
                ],
              ),
            ),
          ),

          // ── Categories section ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
            ),
          ),

          ref.watch(_adminCatsProvider).when(
            loading: () => const SliverToBoxAdapter(child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))),
            error: (e, _) => SliverToBoxAdapter(child: _ErrorRow('$e', onRetry: () => ref.invalidate(_adminCatsProvider))),
            data: (cats) => cats.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Text('No categories yet', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _CategoryCard(
                          cat: cats[i],
                          isDark: isDark,
                          onDelete: () => _deleteCategory(context, ref, cats[i], isDark),
                        ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideY(begin: 0.1),
                        childCount: cats.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: catCols,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.9,
                      ),
                    ),
                  ),
          ),

          // ── Products section ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('All Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
            ),
          ),

          ref.watch(_adminProductsProvider).when(
            loading: () => const SliverToBoxAdapter(child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))),
            error: (e, _) => SliverToBoxAdapter(child: _ErrorRow('$e', onRetry: () => ref.invalidate(_adminProductsProvider))),
            data: (products) => products.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Text('No products yet', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _AdminProductCard(
                          product: products[i],
                          isDark: isDark,
                          onEdit: () => context.push('/admin/products/edit/${products[i].id}').then((_) {
                            ref.invalidate(_adminProductsProvider);
                            ref.invalidate(_adminCatsProvider);
                          }),
                          onDelete: () => _deleteProduct(context, ref, products[i], isDark),
                          onAssignCategory: () => _showAssignCategorySheet(context, ref, products[i], isDark),
                          onView: () => _showProductDetail(context, ref, products[i], isDark),
                        ).animate(delay: Duration(milliseconds: i * 30)).fadeIn().slideY(begin: 0.1),
                        childCount: products.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: prodCols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref, bool isDark) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('New Category', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Category name',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            filled: true,
            fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F7),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          GestureDetector(
            onTap: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                await ref.read(apiServiceProvider).post('/admin/categories', data: {'name': name});
                ref.invalidate(_adminCatsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
              child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, _AdminCategory cat, bool isDark) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('Delete "${cat.name}"?', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w700)),
        content: Text('Products in this category will be moved to Accessories.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiServiceProvider).delete('/admin/categories/${cat.id}');
      ref.invalidate(_adminCatsProvider);
      ref.invalidate(_adminProductsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _deleteProduct(BuildContext context, WidgetRef ref, ProductModel p, bool isDark) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('Delete "${p.name}"?', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w700)),
        content: Text('This product will be deactivated.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiServiceProvider).delete('/admin/products/${p.id}');
      ref.invalidate(_adminProductsProvider);
      ref.invalidate(_adminCatsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _showAssignCategorySheet(BuildContext context, WidgetRef ref, ProductModel product, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AssignCategorySheet(product: product, isDark: isDark, ref: ref),
    );
  }

  void _showProductDetail(BuildContext context, WidgetRef ref, ProductModel product, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => _ProductDetailDialog(product: product, isDark: isDark, ref: ref),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final bool isDark;
  final WidgetRef ref;
  const _AdminHeader({required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(_pendingCountProvider);
    final count = pending.valueOrNull ?? 0;

    return Container(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 20),
      color: isDark ? Colors.black : const Color(0xFFF8F8F8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/'),
            child: Row(
              children: [
                Icon(Icons.arrow_back_rounded, size: 18, color: isDark ? Colors.white54 : Colors.black45),
                const SizedBox(width: 8),
                Text('DRONEHUB', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: isDark ? Colors.white : Colors.black)),
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                  child: const Text('ADMIN', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/admin/orders'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                      const SizedBox(width: 6),
                      Text('Orders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
                    ],
                  ),
                ),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      child: Center(child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final bool filled, isDark;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.filled, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: filled ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: filled ? Colors.white : (isDark ? Colors.white70 : Colors.black54)),
        ),
      ),
    );
  }
}

// ─── Category card ────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final _AdminCategory cat;
  final bool isDark;
  final VoidCallback onDelete;
  const _CategoryCard({required this.cat, required this.isDark, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image grid — takes most of the card
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: _CategoryImageGrid(images: cat.previewImages, isDark: isDark),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                      Text('${cat.productCount} products', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category image grid ──────────────────────────────────────────────────────

class _CategoryImageGrid extends StatelessWidget {
  final List<String> images;
  final bool isDark;
  const _CategoryImageGrid({required this.images, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F7);

    if (images.isEmpty) {
      return Container(
        color: bg,
        child: Center(child: Icon(Icons.airplanemode_active_rounded, size: 40, color: isDark ? Colors.white12 : Colors.black12)),
      );
    }

    if (images.length == 1) {
      return Container(color: bg, child: _Img(images[0]));
    }

    if (images.length == 2) {
      return Row(children: [
        Expanded(child: Container(color: bg, child: _Img(images[0]))),
        Container(width: 1, color: isDark ? Colors.black : Colors.white),
        Expanded(child: Container(color: bg, child: _Img(images[1]))),
      ]);
    }

    if (images.length == 3) {
      return Column(children: [
        Expanded(child: Row(children: [
          Expanded(child: Container(color: bg, child: _Img(images[0]))),
          Container(width: 1, color: isDark ? Colors.black : Colors.white),
          Expanded(child: Container(color: bg, child: _Img(images[1]))),
        ])),
        Container(height: 1, color: isDark ? Colors.black : Colors.white),
        Expanded(child: Container(color: bg, child: _Img(images[2]))),
      ]);
    }

    // 4 images: 2x2
    return Column(children: [
      Expanded(child: Row(children: [
        Expanded(child: Container(color: bg, child: _Img(images[0]))),
        Container(width: 1, color: isDark ? Colors.black : Colors.white),
        Expanded(child: Container(color: bg, child: _Img(images[1]))),
      ])),
      Container(height: 1, color: isDark ? Colors.black : Colors.white),
      Expanded(child: Row(children: [
        Expanded(child: Container(color: bg, child: _Img(images[2]))),
        Container(width: 1, color: isDark ? Colors.black : Colors.white),
        Expanded(child: Container(color: bg, child: _Img(images[3]))),
      ])),
    ]);
  }
}

class _Img extends StatelessWidget {
  final String url;
  const _Img(this.url);

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white24, size: 24),
    );
  }
}

// ─── Admin product card ───────────────────────────────────────────────────────

class _AdminProductCard extends StatefulWidget {
  final ProductModel product;
  final bool isDark;
  final VoidCallback onEdit, onDelete, onAssignCategory, onView;
  const _AdminProductCard({required this.product, required this.isDark, required this.onEdit, required this.onDelete, required this.onAssignCategory, required this.onView});

  @override
  State<_AdminProductCard> createState() => _AdminProductCardState();
}

class _AdminProductCardState extends State<_AdminProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: 200.ms,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? AppColors.accent.withValues(alpha: 0.5) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.5,
            ),
            boxShadow: _hovered ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with ambient blur background
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                  child: p.fullPrimaryImageUrl.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                              child: Image.network(p.fullPrimaryImageUrl, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: isDark ? Colors.black : const Color(0xFFF5F5F7))),
                            ),
                            Container(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06)),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Image.network(p.fullPrimaryImageUrl, fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(Icons.airplanemode_active_rounded, color: isDark ? Colors.white12 : Colors.black12, size: 32)),
                            ),
                          ],
                        )
                      : Container(
                          color: isDark ? Colors.black : const Color(0xFFF5F5F7),
                          child: Icon(Icons.airplanemode_active_rounded, color: isDark ? Colors.white12 : Colors.black12, size: 32),
                        ),
                ),
              ),
              // Info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 6, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.category.toUpperCase(), style: const TextStyle(color: AppColors.accent, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const SizedBox(height: 2),
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black, height: 1.2)),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(p.formatPrice(p.price), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                          Row(
                            children: [
                              _MiniBtn(icon: Icons.edit_outlined, color: AppColors.accent, onTap: widget.onEdit),
                              const SizedBox(width: 4),
                              _MiniBtn(icon: Icons.delete_outline_rounded, color: AppColors.error, onTap: widget.onDelete),
                            ],
                          ),
                        ],
                      ),
                    ],
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

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MiniBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}

// ─── Product detail dialog ────────────────────────────────────────────────────

class _ProductDetailDialog extends StatefulWidget {
  final ProductModel product;
  final bool isDark;
  final WidgetRef ref;
  const _ProductDetailDialog({required this.product, required this.isDark, required this.ref});

  @override
  State<_ProductDetailDialog> createState() => _ProductDetailDialogState();
}

class _ProductDetailDialogState extends State<_ProductDetailDialog> {
  int _imgIdx = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isDark = widget.isDark;
    final imgs = p.allImageUrls;
    final w = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: w > 900 ? 80 : 16, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: w > 700
              ? Row(children: [
                  // Left: image gallery
                  Expanded(flex: 2, child: _buildGallery(imgs, isDark)),
                  // Right: info
                  Expanded(flex: 2, child: _buildInfo(context, p, isDark)),
                ])
              : SingleChildScrollView(child: Column(children: [
                  SizedBox(height: 280, child: _buildGallery(imgs, isDark)),
                  _buildInfo(context, p, isDark),
                ])),
        ),
      ),
    );
  }

  Widget _buildGallery(List<String> imgs, bool isDark) {
    final bg = isDark ? Colors.black : const Color(0xFFF5F5F7);
    if (imgs.isEmpty) {
      return Container(color: bg, child: Center(child: Icon(Icons.airplanemode_active_rounded, size: 80, color: isDark ? Colors.white12 : Colors.black12)));
    }
    return Stack(children: [
      Container(
        color: bg,
        child: Image.network(imgs[_imgIdx], fit: BoxFit.contain, width: double.infinity, height: double.infinity,
            errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, size: 60, color: isDark ? Colors.white24 : Colors.black12)),
      ),
      if (imgs.length > 1) ...[
        // Prev
        Positioned(left: 8, top: 0, bottom: 0, child: Center(
          child: GestureDetector(
            onTap: () => setState(() => _imgIdx = (_imgIdx - 1 + imgs.length) % imgs.length),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
              child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
            ),
          ),
        )),
        // Next
        Positioned(right: 8, top: 0, bottom: 0, child: Center(
          child: GestureDetector(
            onTap: () => setState(() => _imgIdx = (_imgIdx + 1) % imgs.length),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
              child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
            ),
          ),
        )),
        // Dots
        Positioned(bottom: 10, left: 0, right: 0, child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(imgs.length, (i) => Container(
            width: i == _imgIdx ? 16 : 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i == _imgIdx ? AppColors.accent : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        )),
      ],
    ]);
  }

  Widget _buildInfo(BuildContext context, ProductModel p, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(p.category.toUpperCase(), style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ),
            ),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white54 : Colors.black45)),
          ]),
          const SizedBox(height: 10),
          Text(p.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black, height: 1.3)),
          const SizedBox(height: 8),
          Row(children: [
            Text('\$${p.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: p.inStock ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(p.inStock ? 'In Stock (${p.stock})' : 'Out of Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.inStock ? AppColors.success : AppColors.error)),
            ),
          ]),
          if (p.brand != null) ...[
            const SizedBox(height: 6),
            Text('Brand: ${p.brand}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
          ],
          const SizedBox(height: 16),
          if (p.shortDescription != null && p.shortDescription!.isNotEmpty) ...[
            Text(p.shortDescription!, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54, height: 1.5)),
            const SizedBox(height: 8),
          ],
          Text(p.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45, height: 1.5)),
          const SizedBox(height: 24),
          // Action buttons
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/admin/products/edit/${p.id}').then((_) {
                    widget.ref.invalidate(_adminProductsProvider);
                    widget.ref.invalidate(_adminCatsProvider);
                  });
                },
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ])),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => _AssignCategorySheet(product: p, isDark: isDark, ref: widget.ref),
                );
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Center(child: Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54))),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Assign category bottom sheet ─────────────────────────────────────────────

class _AssignCategorySheet extends ConsumerWidget {
  final ProductModel product;
  final bool isDark;
  final WidgetRef ref;
  const _AssignCategorySheet({required this.product, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final catsAsync = innerRef.watch(_adminCatsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Assign to Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black))),
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.black45)),
          ]),
          const SizedBox(height: 6),
          Text('Current: ${product.category}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(height: 16),
          catsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.error)),
            data: (cats) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cats.map((cat) {
                final isCurrent = cat.slug == product.category;
                return GestureDetector(
                  onTap: isCurrent ? null : () async {
                    Navigator.pop(context);
                    try {
                      await ref.read(apiServiceProvider).put('/admin/products/${product.id}', data: {'category': cat.slug});
                      ref.invalidate(_adminProductsProvider);
                      ref.invalidate(_adminCatsProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.accent : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F7)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isCurrent ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                    ),
                    child: Text(cat.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isCurrent ? Colors.white : (isDark ? Colors.white70 : Colors.black54))),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error row ────────────────────────────────────────────────────────────────

class _ErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRow(this.message, {required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12))),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
            child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
