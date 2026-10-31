import '../../utils/parsing_helpers.dart';

/// Database Transfer Object for `products` table.
/// Strictly matches column-level GRANT permissions.
class ProductDto {
  final String id;
  final String name;
  final num price;
  final num? salePrice;
  final num rating;
  final String imageUrl;
  final String sellerStoreId;
  final String? categoryId;
  final String description;
  final int stock;
  final String category;
  final String approvalStatus;
  final bool isActive;
  final DateTime? createdAt;

  ProductDto({
    required this.id,
    required this.name,
    required this.price,
    this.salePrice,
    this.rating = 0.0,
    required this.imageUrl,
    String? sellerStoreId,
    String? sellerId,
    this.categoryId,
    this.description = '',
    this.stock = 0,
    this.category = 'General',
    this.approvalStatus = 'Pending',
    this.isActive = true,
    this.createdAt,
  }) : sellerStoreId = sellerStoreId ?? sellerId ?? '';

  /// Backwards-compatibility alias for sellerStoreId
  String get sellerId => sellerStoreId;

  /// Maps database row (snake_case) to ProductDto.
  factory ProductDto.fromDatabaseMap(Map<String, dynamic> map) {
    return ProductDto(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? map['title'] ?? map['product_name'] ?? '').toString(),
      price: ParsingHelpers.parseDouble(map['price'] ?? map['sale_price'] ?? map['product_price']),
      salePrice: map['sale_price'] != null ? ParsingHelpers.parseDouble(map['sale_price']) : null,
      rating: ParsingHelpers.parseDouble(map['rating']),
      imageUrl: (map['image_url'] ?? map['image'] ?? map['imageUrl'] ?? '').toString(),
      sellerStoreId: (map['seller_store_id'] ?? map['seller_id'] ?? map['sellerId'] ?? '').toString(),
      categoryId: map['category_id']?.toString(),
      description: (map['description'] ?? '').toString(),
      stock: ParsingHelpers.parseInt(map['stock'] ?? map['stock_quantity']),
      category: (map['category'] ?? 'General').toString(),
      approvalStatus: (map['approval_status'] ?? map['approvalStatus'] ?? 'Pending').toString(),
      isActive: map['is_active'] != false,
      createdAt: ParsingHelpers.parseDateTime(map['created_at']),
    );
  }

  /// Grant-matched map for INSERT into public.products.
  /// Server generates id, approval_status ('Pending'), and rating.
  Map<String, dynamic> toInsertMap() {
    final map = <String, dynamic>{
      'seller_store_id': sellerStoreId,
      'name': name,
      'description': description,
      'price': price,
      'stock_quantity': stock,
      'image_url': imageUrl,
      'category': category,
      'is_active': isActive,
    };
    if (categoryId != null && categoryId!.isNotEmpty) {
      map['category_id'] = categoryId;
    }
    if (salePrice != null) {
      map['sale_price'] = salePrice;
    }
    return map;
  }

  /// Grant-matched map for UPDATE into public.products.
  Map<String, dynamic> toUpdateMap() {
    final map = <String, dynamic>{
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category': category,
      'is_active': isActive,
    };
    if (categoryId != null && categoryId!.isNotEmpty) {
      map['category_id'] = categoryId;
    }
    if (salePrice != null) {
      map['sale_price'] = salePrice;
    }
    return map;
  }

  /// Backward-compatibility alias for toInsertMap
  Map<String, dynamic> toDatabaseMap() => toInsertMap();
}
