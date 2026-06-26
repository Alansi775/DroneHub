import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/order_model.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(apiServiceProvider));
});

class ShippingAddress {
  final String name;
  final String email;
  final String? phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? state;
  final String country;
  final String? postalCode;

  const ShippingAddress({
    required this.name,
    required this.email,
    this.phone,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    this.state,
    required this.country,
    this.postalCode,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'city': city,
        'state': state,
        'country': country,
        'postalCode': postalCode,
      };
}

class OrderRepository {
  final ApiService _api;
  OrderRepository(this._api);

  Future<OrderModel> createOrder(ShippingAddress address, {String? notes}) async {
    final res = await _api.post('/orders', data: {
      'shippingAddress': address.toJson(),
      'paymentMethod': 'mock',
      if (notes != null) 'notes': notes,
    });
    return OrderModel.fromJson((res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<List<OrderModel>> getMyOrders({int page = 1}) async {
    final res = await _api.get('/orders', params: {'page': page});
    final data = (res.data as Map<String, dynamic>)['data'] as List;
    return data.map((o) => OrderModel.fromJson(o as Map<String, dynamic>)).toList();
  }

  Future<OrderModel> getOrder(String id) async {
    final res = await _api.get('/orders/$id');
    return OrderModel.fromJson((res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }
}
