import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/cart_model.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiServiceProvider));
});

class CartRepository {
  final ApiService _api;
  CartRepository(this._api);

  Future<CartModel> getCart() async {
    final res = await _api.get('/cart');
    return CartModel.fromJson((res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<void> addItem(String productId, int quantity) async {
    await _api.post('/cart/items', data: {'productId': productId, 'quantity': quantity});
  }

  Future<void> updateItem(String itemId, int quantity) async {
    await _api.put('/cart/items/$itemId', data: {'quantity': quantity});
  }

  Future<void> removeItem(String itemId) async {
    await _api.delete('/cart/items/$itemId');
  }

  Future<void> clearCart() async {
    await _api.delete('/cart');
  }
}
