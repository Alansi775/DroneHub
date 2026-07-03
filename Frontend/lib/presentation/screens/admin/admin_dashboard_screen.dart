import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/api_service.dart';

// ─── DJI-inspired admin palette (separate from public site accent) ────────────

const _blue       = Color(0xFF0070D5);   // DJI Blue — primary actions only
const _borderW    = 0.5;                 // Thin uniform border width
const _maxW       = 1200.0;             // Content max-width constraint

Color _bg(bool dark)          => dark ? const Color(0xFF0A0A0A)  : const Color(0xFFF5F5F7);
Color _surface(bool dark)     => dark ? const Color(0xFF111111)  : Colors.white;
Color _rowHover(bool dark)    => dark ? const Color(0xFF181818)  : const Color(0xFFEBEBEE);
Color _border(bool dark)      => dark ? const Color(0xFF242424)  : const Color(0xFFDEDEE2);
Color _textPrimary(bool dark) => dark ? const Color(0xFFF0F0F0)  : const Color(0xFF111111);
Color _textMuted(bool dark)   => dark ? const Color(0xFF777777)  : const Color(0xFF888888);

// ─── Models ───────────────────────────────────────────────────────────────────

class _AdminCategory {
  final String id, name, slug;
  const _AdminCategory({required this.id, required this.name, required this.slug});
  factory _AdminCategory.fromJson(Map<String, dynamic> j) => _AdminCategory(
    id: j['id'] as String, name: j['name'] as String, slug: j['slug'] as String,
  );
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _adminCatsProvider = FutureProvider.autoDispose<List<_AdminCategory>>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/categories');
  final data = (res.data as Map<String, dynamic>)['data'] as List;
  return data.map((c) => _AdminCategory.fromJson(c as Map<String, dynamic>)).toList();
});

final _adminAllProductsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/products', params: {'limit': '200'});
  final data = (res.data as Map<String, dynamic>)['data'] as List;
  return data.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
});

final _pendingCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/pending-orders-count');
  return ((res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>)['count'] as int? ?? 0;
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboardScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';
  String _activeSlug = '';
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase().trim()));
    _scrollCtrl.addListener(_trackActive);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _trackActive() {
    double closestDy = double.infinity;
    String? closest;
    for (final e in _sectionKeys.entries) {
      final ctx = e.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy >= 0 && dy < closestDy) { closestDy = dy; closest = e.key; }
    }
    if (closest != null && closest != _activeSlug) setState(() => _activeSlug = closest!);
  }

  void _scrollTo(String slug) {
    final ctx = _sectionKeys[slug]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  void _invalidateAll() {
    ref.invalidate(_adminCatsProvider);
    ref.invalidate(_adminAllProductsProvider);
    ref.invalidate(_pendingCountProvider);
  }

  void _showAddCategory(bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _AddCategoryDialog(
        isDark: isDark,
        onAdd: (name) async {
          await ref.read(apiServiceProvider).post('/admin/categories', data: {'name': name});
          ref.invalidate(_adminCatsProvider);
        },
      ),
    );
  }

  Future<void> _deleteCategory(_AdminCategory cat, bool isDark) async {
    final ok = await _confirm(
      title: 'Delete "${cat.name}"?',
      body: 'Products in this category will be moved to Accessories.',
      confirmLabel: 'Delete',
      isDark: isDark,
    );
    if (ok != true) return;
    try {
      await ref.read(apiServiceProvider).delete('/admin/categories/${cat.id}');
      _invalidateAll();
    } catch (e) { if (mounted) _err('$e'); }
  }

  Future<void> _deleteProduct(ProductModel p, bool isDark) async {
    final ok = await _confirm(
      title: 'Delete "${p.name}"?',
      body: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      isDark: isDark,
    );
    if (ok != true) return;
    try {
      await ref.read(apiServiceProvider).delete('/admin/products/${p.id}');
      _invalidateAll();
    } catch (e) { if (mounted) _err('$e'); }
  }

  Future<void> _toggleProduct(ProductModel p) async {
    try {
      await ref.read(apiServiceProvider).put('/admin/products/${p.id}', data: {'isActive': (!p.isActive).toString()});
      _invalidateAll();
    } catch (e) { if (mounted) _err('$e'); }
  }

  Future<bool?> _confirm({required String title, required String body, required String confirmLabel, required bool isDark}) =>
      showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => _ConfirmDialog(isDark: isDark, title: title, body: body, confirmLabel: confirmLabel),
      );

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vw = MediaQuery.of(context).size.width;
    final isWide = vw > 900;

    final catsAsync     = ref.watch(_adminCatsProvider);
    final productsAsync = ref.watch(_adminAllProductsProvider);
    final pending       = ref.watch(_pendingCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: _bg(isDark),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main scrollable content, centered + 1200px capped ──────────
            Column(
              children: [
                // Header (constrained)
                _CommandHeader(
                  isDark: isDark,
                  isWide: isWide,
                  pending: pending,
                  searchCtrl: _searchCtrl,
                  query: _query,
                  onBack: () => context.go('/'),
                  onOrders: () => context.push('/admin/orders'),
                  onAddCategory: () => _showAddCategory(isDark),
                  onAddProduct: () => context.push('/admin/products/add').then((_) => _invalidateAll()),
                ),

                // Body
                Expanded(
                  child: productsAsync.when(
                    loading: () => const _Skeleton(),
                    error: (e, _) => _ErrorView(message: '$e', onRetry: _invalidateAll),
                    data: (allProducts) {
                      final catsData = catsAsync.valueOrNull ?? [];

                      final products = _query.isEmpty
                          ? allProducts
                          : allProducts.where((p) =>
                                p.name.toLowerCase().contains(_query) ||
                                p.category.toLowerCase().contains(_query) ||
                                (p.shortDescription?.toLowerCase().contains(_query) ?? false) ||
                                (p.brand?.toLowerCase().contains(_query) ?? false))
                              .toList();

                      final Map<String, List<ProductModel>> grouped = {};
                      for (final p in products) {
                        grouped.putIfAbsent(p.category, () => []).add(p);
                      }
                      if (_query.isEmpty) {
                        for (final c in catsData) {
                          grouped.putIfAbsent(c.slug, () => []);
                        }
                      }

                      final slugs = grouped.keys.toList()..sort();
                      for (final s in slugs) {
                        _sectionKeys.putIfAbsent(s, () => GlobalKey());
                      }
                      if (_activeSlug.isEmpty && slugs.isNotEmpty) {
                        _activeSlug = slugs.first;
                      }

                      if (products.isEmpty && catsData.isEmpty) {
                        return _EmptyState(isDark: isDark, onAddCategory: () => _showAddCategory(isDark), onAddProduct: () => context.push('/admin/products/add').then((_) => _invalidateAll()));
                      }

                      if (products.isEmpty && _query.isNotEmpty) {
                        return Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.search_off_rounded, size: 48, color: _textMuted(isDark)),
                            const SizedBox(height: 12),
                            Text('No results for "$_query"', style: TextStyle(color: _textMuted(isDark), fontSize: 14)),
                          ]),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollCtrl,
                        padding: EdgeInsets.only(
                          left: isWide ? (vw > _maxW ? (vw - _maxW) / 2 : 0) : 0,
                          right: isWide ? (vw > _maxW ? (vw - _maxW) / 2 + 22 : 22) : 0,
                          bottom: 60,
                        ),
                        itemCount: slugs.length,
                        itemBuilder: (_, i) {
                          final slug = slugs[i];
                          final catObj = catsData.where((c) => c.slug == slug).firstOrNull;
                          final prods = grouped[slug]!;
                          return _CategoryBlock(
                            key: _sectionKeys[slug],
                            slug: slug,
                            displayName: catObj?.name ?? slug,
                            catId: catObj?.id,
                            products: prods,
                            isDark: isDark,
                            isWide: isWide,
                            onDeleteCategory: catObj != null ? () => _deleteCategory(catObj, isDark) : null,
                            onEdit: (p) => context.push('/admin/products/edit/${p.id}').then((_) => _invalidateAll()),
                            onDelete: (p) => _deleteProduct(p, isDark),
                            onToggle: _toggleProduct,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // ── Sidebar — floats at right viewport edge ─────────────────────
            if (isWide)
              Positioned(
                right: 10, top: 0, bottom: 0,
                child: productsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (all) {
                    final catsData = catsAsync.valueOrNull ?? [];
                    final slugs = (() {
                      final Map<String, bool> seen = {};
                      for (final p in all) { seen[p.category] = true; }
                      for (final c in catsData) { seen[c.slug] = true; }
                      return seen.keys.toList()..sort();
                    })();
                    return _Sidebar(
                      slugs: slugs,
                      catsData: catsData,
                      activeSlug: _activeSlug,
                      isDark: isDark,
                      onTap: _scrollTo,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Command-center header ────────────────────────────────────────────────────

class _CommandHeader extends StatelessWidget {
  final bool isDark, isWide;
  final int pending;
  final TextEditingController searchCtrl;
  final String query;
  final VoidCallback onBack, onOrders, onAddCategory, onAddProduct;

  const _CommandHeader({
    required this.isDark, required this.isWide, required this.pending,
    required this.searchCtrl, required this.query,
    required this.onBack, required this.onOrders, required this.onAddCategory, required this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    final vw = MediaQuery.of(context).size.width;
    final hPad = isWide ? (vw > _maxW ? (vw - _maxW) / 2 : 24.0) : 16.0;

    return Column(children: [
      // Row 1: Breadcrumb + Actions
      Padding(
        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
        child: Row(children: [
          // Brand + back
          GestureDetector(
            onTap: onBack,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_ios_new_rounded, size: 11, color: _textMuted(isDark)),
              const SizedBox(width: 7),
              Text('DRONEHUB', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.5, color: _textPrimary(isDark))),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _blue.withValues(alpha: 0.1), border: Border.all(color: _blue.withValues(alpha: 0.3), width: 0.5), borderRadius: BorderRadius.circular(3)),
                child: const Text('ADMIN', style: TextStyle(color: _blue, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ),
            ]),
          ),
          const Spacer(),

          // Orders
          _HeaderBtn(
            isDark: isDark,
            onTap: onOrders,
            child: Stack(clipBehavior: Clip.none, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_outlined, size: 14, color: _textMuted(isDark)),
                if (isWide) ...[const SizedBox(width: 5), Text('Orders', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textMuted(isDark)))],
              ]),
              if (pending > 0)
                Positioned(
                  top: -6, right: -7,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                    child: Center(child: Text('$pending', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 6),

          // + Category
          _HeaderBtn(
            isDark: isDark,
            onTap: onAddCategory,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_rounded, size: 14, color: _blue),
              if (isWide) ...[const SizedBox(width: 4), const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _blue))],
            ]),
          ),
          const SizedBox(width: 6),

          // + Product (filled)
          GestureDetector(
            onTap: onAddProduct,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 14 : 10, vertical: 8),
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                if (isWide) ...[const SizedBox(width: 4), const Text('Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))],
              ]),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 14),

      // Row 2: Search
      Padding(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
        child: TextField(
          controller: searchCtrl,
          style: TextStyle(fontSize: 13, color: _textPrimary(isDark)),
          decoration: InputDecoration(
            hintText: 'Search products, categories, brands...',
            hintStyle: TextStyle(fontSize: 13, color: _textMuted(isDark)),
            prefixIcon: Icon(Icons.search_rounded, size: 16, color: _textMuted(isDark)),
            suffixIcon: query.isNotEmpty
                ? IconButton(icon: Icon(Icons.close_rounded, size: 14, color: _textMuted(isDark)), onPressed: searchCtrl.clear)
                : null,
            filled: true,
            fillColor: _surface(isDark),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _border(isDark), width: _borderW)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : _border(isDark), width: _borderW)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: _blue, width: 1)),
          ),
        ),
      ),

      const SizedBox(height: 12),

      // Divider
      Divider(height: 1, thickness: _borderW, color: _border(isDark)),
    ]);
  }
}

class _HeaderBtn extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;
  final Widget child;
  const _HeaderBtn({required this.isDark, required this.onTap, required this.child});

  @override
  State<_HeaderBtn> createState() => _HeaderBtnState();
}

class _HeaderBtnState extends State<_HeaderBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? _rowHover(widget.isDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border(widget.isDark), width: _borderW),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── Category block ───────────────────────────────────────────────────────────

class _CategoryBlock extends StatelessWidget {
  final String slug, displayName;
  final String? catId;
  final List<ProductModel> products;
  final bool isDark, isWide;
  final VoidCallback? onDeleteCategory;
  final void Function(ProductModel) onEdit, onDelete, onToggle;

  const _CategoryBlock({
    super.key,
    required this.slug, required this.displayName, this.catId,
    required this.products, required this.isDark, required this.isWide,
    this.onDeleteCategory,
    required this.onEdit, required this.onDelete, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final vw = MediaQuery.of(context).size.width;
    final hPad = isWide ? (vw > _maxW ? (vw - _maxW) / 2 : 24.0) : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 28, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header row
          Padding(
            padding: EdgeInsets.only(right: hPad),
            child: Row(
              children: [
                Text(
                  displayName.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2, color: _textMuted(isDark)),
                ),
                const SizedBox(width: 10),
                Text(
                  '${products.length}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _blue.withValues(alpha: 0.85)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Container(height: _borderW, color: _border(isDark))),
                if (onDeleteCategory != null) ...[
                  const SizedBox(width: 12),
                  _DeleteCatBtn(isDark: isDark, onTap: onDeleteCategory!),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Product table
          if (products.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 4, right: hPad),
              child: Text('No products in this category.', style: TextStyle(fontSize: 12, color: _textMuted(isDark), fontStyle: FontStyle.italic)),
            )
          else
            Container(
              margin: EdgeInsets.only(right: hPad),
              decoration: BoxDecoration(
                border: Border.all(color: _border(isDark), width: _borderW),
                borderRadius: BorderRadius.circular(14),
                color: _surface(isDark),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: products.asMap().entries.map((e) {
                  final isLast = e.key == products.length - 1;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ProductRow(
                        product: e.value,
                        isDark: isDark,
                        isWide: isWide,
                        onEdit: () => onEdit(e.value),
                        onDelete: () => onDelete(e.value),
                        onToggle: () => onToggle(e.value),
                      ),
                      if (!isLast) Divider(height: _borderW, thickness: _borderW, color: _border(isDark)),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Product row (table-style) ────────────────────────────────────────────────

class _ProductRow extends StatefulWidget {
  final ProductModel product;
  final bool isDark, isWide;
  final VoidCallback onEdit, onDelete, onToggle;
  const _ProductRow({required this.product, required this.isDark, required this.isWide, required this.onEdit, required this.onDelete, required this.onToggle});

  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: _hovered ? _rowHover(isDark) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: 40, height: 40,
                child: p.fullPrimaryImageUrl.isNotEmpty
                    ? Image.network(p.fullPrimaryImageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _Thumb(isDark: isDark))
                    : _Thumb(isDark: isDark),
              ),
            ),
            const SizedBox(width: 13),

            // Name + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        p.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary(isDark)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.isFeatured) Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Icon(Icons.star_rounded, size: 11, color: _blue.withValues(alpha: 0.7)),
                    ),
                  ]),
                  if (p.brand != null && p.brand!.isNotEmpty)
                    Text(p.brand!, style: TextStyle(fontSize: 10.5, color: _textMuted(isDark)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Price (fixed width on wide)
            if (widget.isWide)
              SizedBox(
                width: 80,
                child: Text(
                  p.formatPrice(p.price),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textPrimary(isDark)),
                  textAlign: TextAlign.right,
                ),
              )
            else
              Text(
                p.formatPrice(p.price),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textPrimary(isDark)),
              ),

            const SizedBox(width: 14),

            // Status badge
            _StatusBadge(active: p.isActive),

            if (widget.isWide) ...[
              const SizedBox(width: 12),
              // Stock
              SizedBox(
                width: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 11,
                      color: p.stock == 0 ? AppColors.error : p.stock < 5 ? AppColors.warning : _textMuted(isDark),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${p.stock}',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: p.stock == 0 ? AppColors.error : p.stock < 5 ? AppColors.warning : _textMuted(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(width: 14),

            // Actions (fade in on hover)
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.2,
              duration: const Duration(milliseconds: 150),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _RowAction(isDark: isDark, icon: Icons.edit_outlined, onTap: widget.onEdit),
                const SizedBox(width: 2),
                _RowAction(
                  isDark: isDark,
                  icon: p.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: p.isActive ? AppColors.error : AppColors.success,
                  onTap: widget.onToggle,
                ),
                const SizedBox(width: 2),
                _RowAction(isDark: isDark, icon: Icons.delete_outline_rounded, color: AppColors.error, onTap: widget.onDelete),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Right sidebar ─────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final List<String> slugs;
  final List<_AdminCategory> catsData;
  final String activeSlug;
  final bool isDark;
  final void Function(String) onTap;

  const _Sidebar({required this.slugs, required this.catsData, required this.activeSlug, required this.isDark, required this.onTap});

  String _label(String slug) => catsData.where((c) => c.slug == slug).map((c) => c.name).firstOrNull ?? slug;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 144,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: slugs.map((s) => _SidebarPill(
          label: _label(s),
          isActive: s == activeSlug,
          isDark: isDark,
          onTap: () => onTap(s),
        )).toList(),
      ),
    );
  }
}

class _SidebarPill extends StatefulWidget {
  final String label;
  final bool isActive, isDark;
  final VoidCallback onTap;
  const _SidebarPill({required this.label, required this.isActive, required this.isDark, required this.onTap});

  @override
  State<_SidebarPill> createState() => _SidebarPillState();
}

class _SidebarPillState extends State<_SidebarPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 26,
            width: _hovered ? 140 : 5,
            decoration: BoxDecoration(
              color: _hovered
                  ? _blue
                  : (widget.isActive ? _blue.withValues(alpha: 0.6) : _border(widget.isDark)),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
            ),
            clipBehavior: Clip.hardEdge,
            child: _hovered
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                      child: Text(
                        widget.label.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

// ─── Add category dialog ──────────────────────────────────────────────────────

class _AddCategoryDialog extends StatefulWidget {
  final bool isDark;
  final Future<void> Function(String) onAdd;
  const _AddCategoryDialog({required this.isDark, required this.onAdd});

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Name is required'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onAdd(name);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: _surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border(isDark), width: _borderW),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 32, offset: const Offset(0, 12))],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Text('New Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary(isDark))),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Icon(Icons.close_rounded, size: 18, color: _textMuted(isDark)),
            ),
          ]),
          const SizedBox(height: 18),

          Text('Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: _textMuted(isDark))),
          const SizedBox(height: 7),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            style: TextStyle(fontSize: 13, color: _textPrimary(isDark)),
            decoration: InputDecoration(
              hintText: 'e.g. Drones, Motors, Cameras...',
              hintStyle: TextStyle(fontSize: 13, color: _textMuted(isDark)),
              filled: true,
              fillColor: _bg(isDark),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border(isDark), width: _borderW)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border(isDark), width: _borderW)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1)),
              errorText: _error,
              errorStyle: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 18),

          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border(isDark), width: _borderW),
                  ),
                  child: Center(child: Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted(isDark)))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _loading ? null : _submit,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: _loading ? _blue.withValues(alpha: 0.5) : _blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─── Confirm dialog ───────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final bool isDark;
  final String title, body, confirmLabel;
  const _ConfirmDialog({required this.isDark, required this.title, required this.body, required this.confirmLabel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: _surface(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border(isDark), width: _borderW),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary(isDark))),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(fontSize: 13, color: _textMuted(isDark), height: 1.5)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).pop(false),
              child: Container(
                height: 38,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: _border(isDark), width: _borderW)),
                child: Center(child: Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMuted(isDark)))),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).pop(true),
              child: Container(
                height: 38,
                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(20)),
                child: Center(child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
              ),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAddCategory, onAddProduct;
  const _EmptyState({required this.isDark, required this.onAddCategory, required this.onAddProduct});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 48, color: _textMuted(isDark)),
        const SizedBox(height: 14),
        Text('No products yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary(isDark))),
        const SizedBox(height: 6),
        Text('Add a category first, then add products to it.', style: TextStyle(fontSize: 13, color: _textMuted(isDark))),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: onAddCategory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: _border(isDark), width: _borderW), borderRadius: BorderRadius.circular(20)),
              child: Text('+ Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary(isDark))),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAddProduct,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(20)),
              child: const Text('+ Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(active ? 'Live' : 'Hidden', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _Thumb extends StatelessWidget {
  final bool isDark;
  const _Thumb({required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    color: _bg(isDark),
    child: Icon(Icons.flight_rounded, size: 16, color: _border(isDark)),
  );
}

class _RowAction extends StatefulWidget {
  final bool isDark;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _RowAction({required this.isDark, required this.icon, required this.onTap, this.color});

  @override
  State<_RowAction> createState() => _RowActionState();
}

class _RowActionState extends State<_RowAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? _textMuted(widget.isDark);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hovered ? c.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(widget.icon, size: 14, color: _hovered ? c : _textMuted(widget.isDark)),
        ),
      ),
    );
  }
}

class _InlineBtn extends StatefulWidget {
  final bool isDark;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _InlineBtn({required this.isDark, required this.icon, required this.color, required this.onTap});

  @override
  State<_InlineBtn> createState() => _InlineBtnState();
}

class _InlineBtnState extends State<_InlineBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(widget.icon, size: 13, color: _hovered ? widget.color : _textMuted(widget.isDark)),
        ),
      ),
    );
  }
}

// Elegant circle-minus delete button for categories
class _DeleteCatBtn extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _DeleteCatBtn({required this.isDark, required this.onTap});

  @override
  State<_DeleteCatBtn> createState() => _DeleteCatBtnState();
}

class _DeleteCatBtnState extends State<_DeleteCatBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = _hovered ? AppColors.error : _textMuted(widget.isDark);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: 22, height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c, width: _borderW),
            color: _hovered ? AppColors.error.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Center(
            child: Container(
              width: 9, height: 1,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(1)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer = isDark ? const Color(0xFF181818) : const Color(0xFFEBEBEE);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      itemCount: 3,
      itemBuilder: (_, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 10),
          child: Row(children: [
            Container(width: 64, height: 9, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Container(width: 16, height: 9, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Container(height: _borderW, color: shimmer)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(border: Border.all(color: shimmer, width: _borderW), borderRadius: BorderRadius.circular(8)),
          child: Column(children: List.generate(3, (i) => Column(mainAxisSize: MainAxisSize.min, children: [
            Container(height: 62, color: shimmer.withValues(alpha: 0.5)),
            if (i < 2) Container(height: _borderW, color: shimmer),
          ]))),
        ),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

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
          decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(6)),
          child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    ]));
  }
}
