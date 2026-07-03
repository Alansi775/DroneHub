import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/api_service.dart';

final _adminProductsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/products', params: {'limit': 200});
  final data = (res.data as Map<String, dynamic>)['data'] as List;
  return data.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
});

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
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
      if (dy >= 0 && dy < closestDy) {
        closestDy = dy;
        closest = e.key;
      }
    }
    if (closest != null && closest != _activeSlug) {
      setState(() => _activeSlug = closest!);
    }
  }

  void _scrollTo(String slug) {
    final ctx = _sectionKeys[slug]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 480), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 720;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(isDark: isDark, searchCtrl: _searchCtrl, query: _query, onAdd: () {
              context.push('/admin/products/add').then((_) => ref.invalidate(_adminProductsProvider));
            }),
            Expanded(
              child: ref.watch(_adminProductsProvider).when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
                data: (all) {
                  final products = _query.isEmpty
                      ? all
                      : all.where((p) =>
                            p.name.toLowerCase().contains(_query) ||
                            p.category.toLowerCase().contains(_query) ||
                            (p.shortDescription?.toLowerCase().contains(_query) ?? false) ||
                            (p.brand?.toLowerCase().contains(_query) ?? false))
                          .toList();

                  final Map<String, List<ProductModel>> grouped = {};
                  for (final p in products) {
                    grouped.putIfAbsent(p.category, () => []).add(p);
                  }
                  final cats = grouped.keys.toList()..sort();

                  for (final c in cats) {
                    _sectionKeys.putIfAbsent(c, () => GlobalKey());
                  }
                  if (_activeSlug.isEmpty && cats.isNotEmpty) _activeSlug = cats.first;

                  if (products.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 52, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 14),
                          Text('No products found', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 15)),
                        ],
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollCtrl,
                        padding: EdgeInsets.fromLTRB(isWide ? 32 : 16, 4, isWide ? 56 : 16, 40),
                        itemCount: cats.length,
                        itemBuilder: (_, i) => _CategorySection(
                          key: _sectionKeys[cats[i]],
                          category: cats[i],
                          products: grouped[cats[i]]!,
                          isDark: isDark,
                          onRefresh: () => ref.invalidate(_adminProductsProvider),
                        ),
                      ),
                      if (isWide)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: _Sidebar(
                            categories: cats,
                            activeSlug: _activeSlug,
                            isDark: isDark,
                            onTap: _scrollTo,
                          ),
                        ),
                    ],
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

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isDark;
  final TextEditingController searchCtrl;
  final String query;
  final VoidCallback onAdd;
  const _Header({required this.isDark, required this.searchCtrl, required this.query, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Row(children: [
                  Icon(Icons.arrow_back_rounded, size: 17, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 5),
                  Text('Dashboard', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(9)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('New Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Products', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 14),
          TextField(
            controller: searchCtrl,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Search by name, category, brand, or description...',
              hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : Colors.black38),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                      onPressed: () => searchCtrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ─── Right sidebar ─────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final List<String> categories;
  final String activeSlug;
  final bool isDark;
  final void Function(String) onTap;
  const _Sidebar({required this.categories, required this.activeSlug, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: categories.map((c) => _SidebarItem(
          label: c.replaceAll('_', ' '),
          isActive: c == activeSlug,
          isDark: isDark,
          onTap: () => onTap(c),
        )).toList(),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final String label;
  final bool isActive, isDark;
  final VoidCallback onTap;
  const _SidebarItem({required this.label, required this.isActive, required this.isDark, required this.onTap});

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
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
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 26,
            width: _hovered ? 140 : 5,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.accent
                  : (widget.isActive
                      ? AppColors.accent.withValues(alpha: 0.65)
                      : (widget.isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.15))),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
            ),
            child: _hovered
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        widget.label.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
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

// ─── Category section ─────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String category;
  final List<ProductModel> products;
  final bool isDark;
  final VoidCallback onRefresh;

  const _CategorySection({
    super.key,
    required this.category,
    required this.products,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 10),
          child: Row(
            children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text(
                category.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2, color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${products.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            ],
          ),
        ),
        ...products.map((p) => _ProductRow(product: p, isDark: isDark, onRefresh: onRefresh)),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─── Product row ──────────────────────────────────────────────────────────────

class _ProductRow extends ConsumerStatefulWidget {
  final ProductModel product;
  final bool isDark;
  final VoidCallback onRefresh;
  const _ProductRow({required this.product, required this.isDark, required this.onRefresh});

  @override
  ConsumerState<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends ConsumerState<_ProductRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _hovered
              ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F4))
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: !p.isActive
                ? AppColors.error.withValues(alpha: 0.25)
                : (_hovered
                    ? AppColors.accent.withValues(alpha: 0.3)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 50, height: 50,
                child: p.fullPrimaryImageUrl.isNotEmpty
                    ? Image.network(p.fullPrimaryImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgFallback(isDark))
                    : _imgFallback(isDark),
              ),
            ),
            const SizedBox(width: 13),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(p.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (p.isFeatured) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.star_rounded, size: 13, color: AppColors.accent)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(p.formatPrice(p.price), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(width: 8),
                    _Pill(label: p.isActive ? 'Live' : 'Hidden', color: p.isActive ? AppColors.success : AppColors.error),
                    const SizedBox(width: 6),
                    _Pill(
                      label: 'Qty ${p.stock}',
                      color: p.stock > 10 ? AppColors.darkTextSecondary : (p.stock > 0 ? AppColors.warning : AppColors.error),
                    ),
                    if (p.brand != null && p.brand!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _Pill(label: p.brand!, color: AppColors.darkTextSecondary),
                    ],
                  ]),
                ],
              ),
            ),

            // Actions (visible on hover)
            AnimatedOpacity(
              opacity: _hovered ? 1 : 0.35,
              duration: const Duration(milliseconds: 180),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _IconBtn(icon: Icons.edit_outlined, onTap: () => context.push('/admin/products/edit/${p.id}').then((_) => widget.onRefresh())),
                const SizedBox(width: 2),
                _IconBtn(
                  icon: p.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: p.isActive ? AppColors.error : AppColors.success,
                  onTap: () => _toggle(context),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgFallback(bool isDark) => Container(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
        child: Icon(Icons.flight_rounded, color: isDark ? Colors.white12 : Colors.black12, size: 22),
      );

  Future<void> _toggle(BuildContext context) async {
    final p = widget.product;
    try {
      await ref.read(apiServiceProvider).put('/admin/products/${p.id}', data: {'isActive': (!p.isActive).toString()});
      widget.onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
      }
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap, this.color});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppColors.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? c.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 17, color: _hovered ? c : (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38)),
        ),
      ),
    );
  }
}
