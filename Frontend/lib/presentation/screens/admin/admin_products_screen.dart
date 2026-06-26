import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/api_service.dart';

final _adminProductsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/products', params: {'limit': 100});
  final data = (res.data as Map<String, dynamic>)['data'] as List;
  return data.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
});

class AdminProductsScreen extends ConsumerWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_adminProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/admin/products/add').then((_) => ref.invalidate(_adminProductsProvider)),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (products) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_adminProductsProvider),
          child: products.isEmpty
              ? const Center(child: Text('No products yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (_, i) => _AdminProductTile(
                    product: products[i],
                    onRefresh: () => ref.invalidate(_adminProductsProvider),
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: () => context.push('/admin/products/add').then((_) => ref.invalidate(_adminProductsProvider)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _AdminProductTile extends ConsumerWidget {
  final ProductModel product;
  final VoidCallback onRefresh;
  const _AdminProductTile({required this.product, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: product.fullPrimaryImageUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: product.fullPrimaryImageUrl, fit: BoxFit.cover)
                : Container(color: const Color(0xFF1A1A1A), child: const Icon(Icons.flight, color: Colors.white24, size: 24)),
          ),
        ),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\$${product.price.toStringAsFixed(2)} · Stock: ${product.stock}', style: const TextStyle(fontSize: 13)),
            if (!product.isActive)
              const Text('INACTIVE', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => context.push('/admin/products/edit/${product.id}').then((_) => onRefresh()),
            ),
            IconButton(
              icon: Icon(product.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: product.isActive ? AppColors.error : AppColors.success),
              onPressed: () => _toggleActive(context, ref, product),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, ProductModel product) async {
    try {
      await ref.read(apiServiceProvider).put('/admin/products/${product.id}', data: {'isActive': (!product.isActive).toString()});
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
      }
    }
  }
}
