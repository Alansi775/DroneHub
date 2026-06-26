import 'product_model.dart';

class CartItem {
  final String id;
  final String productId;
  final int quantity;
  final ProductModel product;

  const CartItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.product,
  });

  double get itemTotal => product.price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'],
        productId: json['product_id'],
        quantity: json['quantity'],
        product: ProductModel.fromJson(json['product'] as Map<String, dynamic>),
      );
}

class CartModel {
  final List<CartItem> items;
  final double subtotal;

  const CartModel({required this.items, required this.subtotal});

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;

  factory CartModel.fromJson(Map<String, dynamic> json) => CartModel(
        items: (json['items'] as List<dynamic>)
            .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        subtotal: double.parse(json['subtotal'].toString()),
      );

  static CartModel empty() => const CartModel(items: [], subtotal: 0);
}
