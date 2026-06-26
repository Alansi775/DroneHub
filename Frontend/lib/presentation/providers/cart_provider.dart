import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cart_model.dart';
import '../../data/repositories/cart_repository.dart';

class CartNotifier extends StateNotifier<AsyncValue<CartModel>> {
  final CartRepository _repo;

  CartNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getCart());
  }

  Future<void> addItem(String productId, {int quantity = 1}) async {
    await _repo.addItem(productId, quantity);
    await load();
  }

  Future<void> updateItem(String itemId, int quantity) async {
    await _repo.updateItem(itemId, quantity);
    await load();
  }

  Future<void> removeItem(String itemId) async {
    await _repo.removeItem(itemId);
    await load();
  }

  Future<void> clear() async {
    await _repo.clearCart();
    state = AsyncValue.data(CartModel.empty());
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<CartModel>>((ref) {
  return CartNotifier(ref.watch(cartRepositoryProvider));
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).when(
    data: (cart) => cart.itemCount,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
