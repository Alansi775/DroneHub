import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/product_model.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(apiServiceProvider));
});

class PaginatedProducts {
  final List<ProductModel> products;
  final int total;
  final int page;
  final int totalPages;

  const PaginatedProducts({
    required this.products,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

class ProductRepository {
  final ApiService _api;
  ProductRepository(this._api);

  Future<PaginatedProducts> getProducts({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
    double? minPrice,
    double? maxPrice,
    String sort = 'created_at',
    String order = 'DESC',
    bool? featured,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (category != null) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      'sort': sort,
      'order': order,
      if (featured != null) 'featured': featured,
    };

    final res = await _api.get('/products', params: params);
    final data = res.data as Map<String, dynamic>;
    final pagination = data['pagination'] as Map<String, dynamic>;

    return PaginatedProducts(
      products: (data['data'] as List).map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList(),
      total: pagination['total'] as int,
      page: pagination['page'] as int,
      totalPages: pagination['totalPages'] as int,
    );
  }

  Future<ProductModel> getProductBySlug(String slug) async {
    final res = await _api.get('/products/slug/$slug');
    return ProductModel.fromJson((res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<List<String>> getCategories() async {
    final res = await _api.get('/products/categories');
    return List<String>.from((res.data as Map<String, dynamic>)['data'] as List);
  }
}
