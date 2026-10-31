import '../../utils/parsing_helpers.dart';

/// Database Transfer Object for `seller_stores` table.
/// EXCLUDES password fields to prevent credential serialization.
class SellerStoreDto {
  final String id;
  final String ownerId;
  final String shopName;
  final String shopSlug;
  final String businessName;
  final String businessAddress;
  final String city;
  final String country;
  final String category;
  final String shopDescription;
  final String shopLogo;
  final String shopBanner;
  final bool isApproved;
  final String kycStatus;
  final double commissionRate;
  final double balance;
  final double pendingPayout;
  final double lastPayout;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SellerStoreDto({
    required this.id,
    String? ownerId,
    String? userId,
    required this.shopName,
    this.shopSlug = '',
    this.businessName = '',
    this.businessAddress = '',
    this.city = '',
    this.country = '',
    this.category = '',
    this.shopDescription = '',
    this.shopLogo = '',
    this.shopBanner = '',
    this.isApproved = false,
    this.kycStatus = 'Pending',
    this.commissionRate = 10.0,
    this.balance = 0.0,
    this.pendingPayout = 0.0,
    this.lastPayout = 0.0,
    this.createdAt,
    this.updatedAt,
  }) : ownerId = ownerId ?? userId ?? '';

  /// Backwards-compatibility alias for ownerId
  String get userId => ownerId;

  /// Maps database row (snake_case) to SellerStoreDto.
  factory SellerStoreDto.fromDatabaseMap(Map<String, dynamic> map) {
    return SellerStoreDto(
      id: (map['id'] ?? '').toString(),
      ownerId: (map['owner_id'] ?? map['user_id'] ?? map['seller_id'] ?? '').toString(),
      shopName: (map['shop_name'] ?? map['store_name'] ?? '').toString(),
      shopSlug: (map['shop_slug'] ?? map['store_slug'] ?? '').toString(),
      businessName: (map['business_name'] ?? '').toString(),
      businessAddress: (map['business_address'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      country: (map['country'] ?? '').toString(),
      category: (map['category'] ?? map['store_category'] ?? '').toString(),
      shopDescription: (map['shop_description'] ?? '').toString(),
      shopLogo: (map['shop_logo'] ?? '').toString(),
      shopBanner: (map['shop_banner'] ?? '').toString(),
      isApproved: map['is_approved'] == true,
      kycStatus: (map['kyc_status'] ?? 'Pending').toString(),
      commissionRate: ParsingHelpers.parseDouble(map['commission_rate'], defaultValue: 10.0),
      balance: ParsingHelpers.parseDouble(map['balance']),
      pendingPayout: ParsingHelpers.parseDouble(map['pending_payout']),
      lastPayout: ParsingHelpers.parseDouble(map['last_payout']),
      createdAt: ParsingHelpers.parseDateTime(map['created_at']),
      updatedAt: ParsingHelpers.parseDateTime(map['updated_at']),
    );
  }

  /// Grant-matched map for INSERT into public.seller_stores.
  /// Server manages id, is_approved, kyc_status, commission_rate, balance, pending_payout.
  Map<String, dynamic> toInsertMap() {
    return {
      'owner_id': ownerId,
      'shop_name': shopName,
      'shop_slug': shopSlug,
      'business_name': businessName,
      'business_address': businessAddress,
      'city': city,
      'country': country,
      'category': category,
      'shop_description': shopDescription,
      'shop_logo': shopLogo,
      'shop_banner': shopBanner,
    };
  }

  /// Grant-matched map for UPDATE into public.seller_stores.
  Map<String, dynamic> toUpdateMap() {
    return {
      'shop_name': shopName,
      'shop_slug': shopSlug,
      'business_name': businessName,
      'business_address': businessAddress,
      'city': city,
      'country': country,
      'category': category,
      'shop_description': shopDescription,
      'shop_logo': shopLogo,
      'shop_banner': shopBanner,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Complete database map representation
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'shop_name': shopName,
      'shop_slug': shopSlug,
      'business_name': businessName,
      'business_address': businessAddress,
      'city': city,
      'country': country,
      'category': category,
      'shop_description': shopDescription,
      'shop_logo': shopLogo,
      'shop_banner': shopBanner,
      'is_approved': isApproved,
      'kyc_status': kycStatus,
      'commission_rate': commissionRate,
      'balance': balance,
      'pending_payout': pendingPayout,
      'last_payout': lastPayout,
    };
  }
}
