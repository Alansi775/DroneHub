import 'package:intl/intl.dart';

class ProductImage {
  final String id;
  final String url;
  final String? altText;
  final bool isPrimary;
  final int sortOrder;

  const ProductImage({
    required this.id,
    required this.url,
    this.altText,
    required this.isPrimary,
    required this.sortOrder,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
        id: json['id'] as String,
        url: json['url'] as String,
        altText: json['alt_text'] as String?,
        isPrimary: json['is_primary'] as bool? ?? false,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class ProductModel {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String? shortDescription;
  final double price;
  final double? comparePrice;
  final int stock;
  final String category;
  final String currency;
  final String? brand;
  final bool isActive;
  final bool isFeatured;
  final int soldCount;
  final List<ProductImage> images;
  final Map<String, dynamic>? specifications;
  final DateTime createdAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    this.shortDescription,
    required this.price,
    this.comparePrice,
    required this.stock,
    required this.category,
    this.currency = 'USD',
    this.brand,
    required this.isActive,
    required this.isFeatured,
    required this.soldCount,
    required this.images,
    this.specifications,
    required this.createdAt,
  });

  bool get inStock => stock > 0;
  bool get hasDiscount => comparePrice != null && comparePrice! > price;
  double get discountPercent =>
      hasDiscount ? ((comparePrice! - price) / comparePrice! * 100).roundToDouble() : 0;

  String get currencySymbol {
    switch (currency) {
      case 'EUR': return '€';
      case 'TRY': return '₺';
      default: return '\$';
    }
  }

  String formatPrice(double v) {
    // Integer part with thousands separator, up to 4 decimal places, strip trailing zeros
    final fmt = NumberFormat('#,##0.####', 'en_US');
    return '$currencySymbol${fmt.format(v)}';
  }

  String? get primaryImageUrl {
    if (images.isEmpty) return null;
    final primary = images.where((i) => i.isPrimary).toList();
    if (primary.isNotEmpty) return primary.first.url;
    return images.first.url;
  }

  static const String _imgBase = 'http://localhost:5001';

  String get fullPrimaryImageUrl {
    final url = primaryImageUrl;
    if (url == null) return '';
    if (url.startsWith('http')) return url;
    return '$_imgBase$url';
  }

  List<String> get allImageUrls => images.map((i) {
        if (i.url.startsWith('http')) return i.url;
        return '$_imgBase${i.url}';
      }).toList();

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return (v.isNaN || v.isInfinite) ? 0.0 : v.toDouble();
    final parsed = double.tryParse(v.toString());
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return 0.0;
    return parsed;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: (json['description'] as String?) ?? '',
        shortDescription: json['short_description'] as String?,
        price: _d(json['price']),
        comparePrice: json['compare_price'] != null ? _d(json['compare_price']) : null,
        stock: (json['stock'] as num?)?.toInt() ?? 0,
        category: (json['category'] as String?) ?? '',
        currency: (json['currency'] as String?) ?? 'USD',
        brand: json['brand'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        isFeatured: json['is_featured'] as bool? ?? false,
        soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
        images: (json['images'] as List<dynamic>? ?? [])
            .map((i) => ProductImage.fromJson(i as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        specifications: json['specifications'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(
            (json['created_at'] ?? json['createdAt'] ?? '2024-01-01').toString()),
      );
}