class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final String? productImage;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'],
        productId: json['product_id'],
        productName: json['product_name'],
        productImage: json['product_image'],
        quantity: json['quantity'],
        unitPrice: double.parse(json['unit_price'].toString()),
        totalPrice: double.parse(json['total_price'].toString()),
      );
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final double subtotal;
  final double shippingCost;
  final double tax;
  final double total;
  final String shippingName;
  final String shippingEmail;
  final String? shippingPhone;
  final String shippingAddressLine1;
  final String? shippingAddressLine2;
  final String shippingCity;
  final String? shippingState;
  final String shippingCountry;
  final String? shippingPostalCode;
  final List<OrderItem> items;
  final DateTime createdAt;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.shippingCost,
    required this.tax,
    required this.total,
    required this.shippingName,
    required this.shippingEmail,
    this.shippingPhone,
    required this.shippingAddressLine1,
    this.shippingAddressLine2,
    required this.shippingCity,
    this.shippingState,
    required this.shippingCountry,
    this.shippingPostalCode,
    required this.items,
    required this.createdAt,
  });

  bool get isPaid => paymentStatus == 'paid';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'processing': return 'Processing';
      case 'shipped': return 'Shipped';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      case 'refunded': return 'Refunded';
      default: return status;
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'],
        orderNumber: json['order_number'],
        status: json['status'],
        paymentStatus: json['payment_status'],
        subtotal: double.parse(json['subtotal'].toString()),
        shippingCost: double.parse(json['shipping_cost'].toString()),
        tax: double.parse(json['tax'].toString()),
        total: double.parse(json['total'].toString()),
        shippingName: json['shipping_name'],
        shippingEmail: json['shipping_email'],
        shippingPhone: json['shipping_phone'],
        shippingAddressLine1: json['shipping_address_line1'],
        shippingAddressLine2: json['shipping_address_line2'],
        shippingCity: json['shipping_city'],
        shippingState: json['shipping_state'],
        shippingCountry: json['shipping_country'],
        shippingPostalCode: json['shipping_postal_code'],
        items: (json['items'] as List<dynamic>? ?? [])
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}
