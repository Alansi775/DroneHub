import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/product/product_card.dart';
import '../../widgets/common/loading_shimmer.dart';

// Fetches only categories that actually have products
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/products/categories');
  final data = (res.data as Map<String, dynamic>)['data'] as List;
  return data.map((e) => e.toString()).toList();
});

final _productsStateProvider = StateProvider<_Filter>((ref) => const _Filter());

class _Filter {
  final String? category;
  final String? search;
  final String sort;
  const _Filter({this.category, this.search, this.sort = 'created_at'});
  _Filter copyWith({String? category, String? search, String? sort, bool clearCategory = false}) => _Filter(
        category: clearCategory ? null : (category ?? this.category),
        search: search ?? this.search,
        sort: sort ?? this.sort,
      );
}

final _productsDataProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final f = ref.watch(_productsStateProvider);
  final res = await ref.watch(productRepositoryProvider).getProducts(
        category: f.category,
        search: f.search,
        sort: f.sort,
        limit: 60,
      );
  return res.products;
});

class ProductsScreen extends ConsumerStatefulWidget {
  final String? category;
  final String? search;
  const ProductsScreen({super.key, this.category, this.search});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.search);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_productsStateProvider.notifier).state =
          _Filter(category: widget.category, search: widget.search);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filter = ref.watch(_productsStateProvider);
    final products = ref.watch(_productsDataProvider);
    final w = MediaQuery.of(context).size.width;
    final cols = w > 1200 ? 4 : w > 800 ? 3 : 2;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Column(
        children: [
          // Top area — respects floating navbar
          _ShopHeader(
            isDark: isDark,
            searchCtrl: _searchCtrl,
            onSearch: (v) => ref.read(_productsStateProvider.notifier).update((s) => s.copyWith(search: v)),
            onClear: () {
              _searchCtrl.clear();
              ref.read(_productsStateProvider.notifier).update((s) => s.copyWith(search: ''));
            },
          ),

          // Category chips
          _CategoryStrip(selected: filter.category, isDark: isDark),

          const SizedBox(height: 12),

          // Grid
          Expanded(
            child: products.when(
              loading: () => GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols, childAspectRatio: 0.62, crossAxisSpacing: 12, mainAxisSpacing: 12,
                ),
                itemCount: 8,
                itemBuilder: (_, __) => const ProductCardShimmer(),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 52, color: isDark ? Colors.white24 : Colors.black12),
                    const SizedBox(height: 12),
                    Text('Cannot connect to server', style: TextStyle(color: isDark ? Colors.white54 : Colors.black38, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Make sure the backend is running', style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.black26)),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => ref.invalidate(_productsDataProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 52, color: isDark ? Colors.white24 : Colors.black12),
                          const SizedBox(height: 12),
                          Text('No products found', style: TextStyle(color: isDark ? Colors.white54 : Colors.black38, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(_productsDataProvider),
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols, childAspectRatio: 0.62, crossAxisSpacing: 12, mainAxisSpacing: 12,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) => ProductCard(product: list[i], index: i)
                            .animate().fadeIn(delay: Duration(milliseconds: 40 * i)).slideY(begin: 0.1),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _ShopHeader extends StatelessWidget {
  final bool isDark;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  const _ShopHeader({required this.isDark, required this.searchCtrl, required this.onSearch, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 76, 20, 12),
      color: isDark ? Colors.black : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shop',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          // Search bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: TextField(
              controller: searchCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search drones, motors, ESC...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: onClear,
                        child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: onSearch,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Strip ───────────────────────────────────────────────────────────

class _CategoryStrip extends ConsumerWidget {
  final String? selected;
  final bool isDark;
  const _CategoryStrip({this.selected, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(categoriesProvider);

    return catsAsync.when(
      loading: () => const SizedBox(height: 34),
      error: (_, __) => const SizedBox(height: 34),
      data: (cats) {
        // "All" + whatever categories exist in the DB
        final items = ['', ...cats];

        return SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final val = items[i];
              final label = val.isEmpty ? 'All' : val;
              final active = val.isEmpty
                  ? (selected == null || selected!.isEmpty)
                  : val == selected;

              return GestureDetector(
                onTap: () => ref.read(_productsStateProvider.notifier).update((s) =>
                    s.copyWith(category: val.isEmpty ? null : val, clearCategory: val.isEmpty)),
                child: AnimatedContainer(
                  duration: 200.ms,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: active ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
