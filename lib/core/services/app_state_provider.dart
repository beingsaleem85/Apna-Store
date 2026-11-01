import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/controllers/seller_controller.dart';
import 'package:apna_store/core/services/supabase_checkout_service.dart';
import 'package:apna_store/core/services/supabase_orders_service.dart';
import 'package:apna_store/core/services/product_repository.dart';
import 'package:apna_store/core/services/supabase_voucher_service.dart';

// Helper models for the state provider
class AppStore {
  final String id;
  String shopName;
  String shopLogo;
  String shopBanner;
  String shopDescription;
  bool isApproved;
  String kycStatus; // 'Pending', 'Approved', 'Rejected'
  String? rejectionReason;
  bool isVacationMode;
  double commissionRate; // pre-determined commission percentage
  double balance;
  double pendingPayout;
  double lastPayout;
  int followersCount;

  // Seller Onboarding & Registration details
  String? ownerId;
  bool isSuspended;
  String? fullName;
  String? businessName;
  String? email;
  String? mobileNumber;
  String? country;
  String? city;
  String? businessAddress;
  String? storeCategory;
  String? storeSlug;
  String? storeContactNumber;
  String? storeEmail;

  AppStore({
    required this.id,
    required this.shopName,
    this.shopLogo = '',
    this.shopBanner = '',
    this.shopDescription = '',
    this.isApproved = false,
    this.kycStatus = 'Pending',
    this.rejectionReason,
    this.isVacationMode = false,
    this.commissionRate = 10.00,
    this.balance = 0.0,
    this.pendingPayout = 0.0,
    this.lastPayout = 0.0,
    this.followersCount = 0,
    this.ownerId,
    this.isSuspended = false,
    this.fullName,
    this.businessName,
    this.email,
    this.mobileNumber,
    this.country,
    this.city,
    this.businessAddress,
    this.storeCategory,
    this.storeSlug,
    this.storeContactNumber,
    this.storeEmail,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shopName': shopName,
      'shopLogo': shopLogo,
      'shopBanner': shopBanner,
      'shopDescription': shopDescription,
      'isApproved': isApproved,
      'kycStatus': kycStatus,
      'rejectionReason': rejectionReason,
      'isVacationMode': isVacationMode,
      'commissionRate': commissionRate,
      'balance': balance,
      'pendingPayout': pendingPayout,
      'lastPayout': lastPayout,
      'followersCount': followersCount,
      'fullName': fullName,
      'businessName': businessName,
      'email': email,
      'mobileNumber': mobileNumber,
      'country': country,
      'city': city,
      'businessAddress': businessAddress,
      'storeCategory': storeCategory,
      'storeSlug': storeSlug,
      'storeContactNumber': storeContactNumber,
      'storeEmail': storeEmail,
    };
  }

  factory AppStore.fromJson(Map<String, dynamic> json) {
    return AppStore(
      id: (json['id'] ?? '').toString(),
      shopName: (json['shopName'] ?? json['shop_name'] ?? '').toString(),
      shopLogo: (json['shopLogo'] ?? json['shop_logo'] ?? json['shop_logo_path'] ?? '').toString(),
      shopBanner: (json['shopBanner'] ?? json['shop_banner'] ?? json['shop_banner_path'] ?? '').toString(),
      shopDescription: (json['shopDescription'] ?? json['shop_description'] ?? '').toString(),
      isApproved: json['isApproved'] ?? json['is_approved'] ?? false,
      kycStatus: (json['kycStatus'] ?? json['kyc_status'] ?? 'Pending').toString(),
      rejectionReason: json['rejectionReason'] ?? json['rejection_reason'],
      isVacationMode: json['isVacationMode'] ?? json['is_vacation_mode'] ?? false,
      commissionRate: (json['commissionRate'] ?? json['commission_rate'] as num?)?.toDouble() ?? 10.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      pendingPayout: (json['pendingPayout'] as num?)?.toDouble() ?? 0.0,
      lastPayout: (json['lastPayout'] as num?)?.toDouble() ?? 0.0,
      followersCount: json['followersCount'] ?? json['followers_count'] ?? 0,
      ownerId: (json['ownerId'] ?? json['owner_id'] ?? json['user_id'])?.toString(),
      isSuspended: json['isSuspended'] ?? json['is_suspended'] ?? false,
      fullName: json['fullName'] ?? json['full_name'],
      businessName: json['businessName'] ?? json['business_name'],
      email: json['email'],
      mobileNumber: json['mobileNumber'] ?? json['mobile_number'],
      country: json['country'],
      city: json['city'],
      businessAddress: json['businessAddress'] ?? json['business_address'],
      storeCategory: json['storeCategory'] ?? json['category'],
      storeSlug: json['storeSlug'] ?? json['shop_slug'],
      storeContactNumber: json['storeContactNumber'] ?? json['store_contact_number'],
      storeEmail: json['storeEmail'] ?? json['store_email'],
    );
  }
}

class ProductVariation {
  final String name; // e.g. "Color" or "Size"
  final List<String> values; // e.g. ["Red", "Blue"] or ["S", "M", "L"]

  ProductVariation({required this.name, required this.values});
}

class AppProduct {
  final String id;
  final String sellerId;
  String name;
  String price;
  String description;
  String imageUrl;
  String rating;
  int stock;
  String category;
  String approvalStatus; // 'Draft', 'Pending', 'Approved', 'Rejected'
  String? rejectionReason;
  List<ProductVariation> variations;
  Map<String, double> wholesalePrices; // e.g., {"5+": 1300.0, "10+": 1100.0}

  List<String> additionalImages;
  String videoUrl;

  AppProduct({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    this.rating = '5.0',
    this.stock = 100,
    required this.category,
    this.approvalStatus = 'Pending',
    this.rejectionReason,
    required this.variations,
    required this.wholesalePrices,
    this.additionalImages = const [],
    this.videoUrl = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerId': sellerId,
      'seller_store_id': sellerId,
      'name': name,
      'title': name,
      'price': price,
      'description': description,
      'imageUrl': imageUrl,
      'image_url': imageUrl,
      'rating': rating,
      'stock': stock,
      'stock_quantity': stock,
      'category': category,
      'approvalStatus': approvalStatus,
      'approval_status': approvalStatus,
      'rejectionReason': rejectionReason,
      'additionalImages': additionalImages,
      'videoUrl': videoUrl,
    };
  }

  factory AppProduct.fromJson(Map<String, dynamic> json) {
    dynamic rawPrice = json['price'] ?? json['sale_price'] ?? json['product_price'] ?? json['basePrice'];
    String priceStr = '0';
    if (rawPrice != null) {
      if (rawPrice is num) {
        priceStr = rawPrice % 1 == 0 ? rawPrice.toInt().toString() : rawPrice.toString();
      } else {
        priceStr = rawPrice.toString().trim();
      }
    }

    final String nameStr = (json['name'] ?? json['title'] ?? json['product_name'] ?? json['shop_name'] ?? '').toString();
    final String imageStr = (json['imageUrl'] ?? json['image_url'] ?? json['image'] ?? json['product_image'] ?? '').toString();
    final String sellerIdStr = (json['sellerId'] ?? json['seller_store_id'] ?? json['seller_id'] ?? json['owner_id'] ?? '').toString();

    int stockVal = 0;
    if (json['stock'] != null && json['stock'] is num) {
      stockVal = (json['stock'] as num).toInt();
    } else if (json['stock_quantity'] != null && json['stock_quantity'] is num) {
      stockVal = (json['stock_quantity'] as num).toInt();
    }

    final String categoryStr = (json['category'] ?? 'General').toString();
    final String approvalStr = (json['approvalStatus'] ?? json['approval_status'] ?? 'Pending').toString();

    return AppProduct(
      id: (json['id'] ?? '').toString(),
      sellerId: sellerIdStr,
      name: nameStr.isNotEmpty ? nameStr : 'Product',
      price: priceStr,
      description: (json['description'] ?? '').toString(),
      imageUrl: imageStr,
      rating: (json['rating'] ?? '0.0').toString(),
      stock: stockVal,
      category: categoryStr,
      approvalStatus: approvalStr,
      rejectionReason: json['rejectionReason'] ?? json['rejection_reason'],
      variations: [],
      wholesalePrices: {},
      additionalImages: List<String>.from(json['additionalImages'] ?? json['additional_images'] ?? []),
      videoUrl: (json['videoUrl'] ?? json['video_url'] ?? '').toString(),
    );
  }
}

class AppOrder {
  final String id;
  final String productId;
  final String productName;
  final double productPrice;
  final String sellerId;
  final String buyerName;
  final String shippingAddress;
  final String shippingSpeed; // 'Standard', 'Express'
  final String paymentMethod; // 'COD', 'Prepaid', 'BNPL'
  final double couponDiscount;
  final double commissionDeducted;
  final double finalPayout;
  String orderStatus; // 'Pending', 'Confirmed', 'Packed', 'ReadyToShip', 'Shipped', 'Delivered', 'Cancelled', 'Returned'
  String? trackingNumber;
  String? shippingPartner;
  String? returnReason;
  String? disputeStatus; // 'None', 'Pending', 'Resolved'

  AppOrder({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.sellerId,
    required this.buyerName,
    required this.shippingAddress,
    required this.shippingSpeed,
    required this.paymentMethod,
    required this.couponDiscount,
    required this.commissionDeducted,
    required this.finalPayout,
    this.orderStatus = 'Pending',
    this.trackingNumber,
    this.shippingPartner = 'Marketplace Express',
    this.returnReason,
    this.disputeStatus = 'None',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_price': productPrice,
      'seller_id': sellerId,
      'buyer_name': buyerName,
      'shipping_address': shippingAddress,
      'shipping_speed': shippingSpeed,
      'payment_method': paymentMethod,
      'coupon_discount': couponDiscount,
      'commission_deducted': commissionDeducted,
      'final_payout': finalPayout,
      'order_status': orderStatus,
      'tracking_number': trackingNumber,
      'shipping_partner': shippingPartner,
      'return_reason': returnReason,
      'dispute_status': disputeStatus,
    };
  }

  factory AppOrder.fromJson(Map<String, dynamic> json) {
    return AppOrder(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? json['productId'] ?? '').toString(),
      productName: (json['product_name'] ?? json['productName'] ?? '').toString(),
      productPrice: (json['product_price'] ?? json['productPrice'] as num?)?.toDouble() ?? 0.0,
      sellerId: (json['seller_id'] ?? json['sellerId'] ?? '').toString(),
      buyerName: (json['buyer_name'] ?? json['buyerName'] ?? '').toString(),
      shippingAddress: (json['shipping_address'] ?? json['shippingAddress'] ?? '').toString(),
      shippingSpeed: (json['shipping_speed'] ?? json['shippingSpeed'] ?? 'Standard').toString(),
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'] ?? 'COD').toString(),
      couponDiscount: (json['coupon_discount'] ?? json['couponDiscount'] as num?)?.toDouble() ?? 0.0,
      commissionDeducted: (json['commission_deducted'] ?? json['commissionDeducted'] as num?)?.toDouble() ?? 0.0,
      finalPayout: (json['final_payout'] ?? json['finalPayout'] as num?)?.toDouble() ?? 0.0,
      orderStatus: (json['order_status'] ?? json['orderStatus'] ?? 'Pending').toString(),
      trackingNumber: json['tracking_number'] ?? json['trackingNumber'],
      shippingPartner: json['shipping_partner'] ?? json['shippingPartner'] ?? 'Marketplace Express',
      returnReason: json['return_reason'] ?? json['returnReason'],
      disputeStatus: json['dispute_status'] ?? json['disputeStatus'] ?? 'None',
    );
  }
}

class ChatMessage {
  final String sender; // 'buyer', 'seller', 'admin'
  final String message;
  final DateTime timestamp;

  ChatMessage({required this.sender, required this.message, required this.timestamp});
}

class AppAddress {
  final String id;
  String title;
  String recipientName;
  String phone;
  String addressLine;
  String city;
  String province;
  String unionCouncil;
  String landmark;
  String gateInstructions;
  String deliverySlot; // 'Anytime', 'Morning', 'Evening'
  String postalCode;
  bool isDefault;

  AppAddress({
    required this.id,
    required this.title,
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.city,
    this.province = 'Punjab',
    required this.unionCouncil,
    required this.landmark,
    required this.gateInstructions,
    required this.deliverySlot,
    this.postalCode = '54000',
    this.isDefault = false,
  });
}

class AppStateProvider extends ChangeNotifier {
  final CatalogController catalogController;
  final CartController cartController;
  final OrdersController ordersController;
  final SellerController sellerController;

  AppStateProvider({
    CatalogController? catalogController,
    CartController? cartController,
    OrdersController? ordersController,
    SellerController? sellerController,
  })  : catalogController = catalogController ?? CatalogController(),
        cartController = cartController ?? CartController(),
        ordersController = ordersController ?? OrdersController(),
        sellerController = sellerController ?? SellerController() {
    this.catalogController.addListener(notifyListeners);
    this.cartController.addListener(notifyListeners);
    this.ordersController.addListener(notifyListeners);
    this.sellerController.addListener(notifyListeners);
    _initializeLocalCache();
  }

  void updateDependencies({
    required CatalogController catalogController,
    required CartController cartController,
    required OrdersController ordersController,
    required SellerController sellerController,
  }) {
    if (this.catalogController != catalogController) {
      this.catalogController.removeListener(notifyListeners);
      catalogController.addListener(notifyListeners);
    }
    if (this.cartController != cartController) {
      this.cartController.removeListener(notifyListeners);
      cartController.addListener(notifyListeners);
    }
    if (this.ordersController != ordersController) {
      this.ordersController.removeListener(notifyListeners);
      ordersController.addListener(notifyListeners);
    }
    if (this.sellerController != sellerController) {
      this.sellerController.removeListener(notifyListeners);
      sellerController.addListener(notifyListeners);
    }
  }

  @override
  void dispose() {
    catalogController.removeListener(notifyListeners);
    cartController.removeListener(notifyListeners);
    ordersController.removeListener(notifyListeners);
    sellerController.removeListener(notifyListeners);
    super.dispose();
  }

  // Global States (Databases)
  final Map<String, List<ChatMessage>> _chats = {};
  final List<String> _announcements = [];
  final Map<String, double> _vouchers = {};



  // Cart & Wishlist Delegates (Single source of truth in CartController)
  List<AppProduct> get cartProducts => cartController.cartProducts;
  List<AppProduct> get wishlistProducts => cartController.wishlistProducts;

  // Seller Authentication & Store Setup
  String? _loggedInSellerId;
  String? get loggedInSellerId => _loggedInSellerId;

  User? get _safeCurrentUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isSellerLoggedIn {
    if (_loggedInSellerId != null) return true;
    final currentUser = _safeCurrentUser;
    if (currentUser != null) {
      final store = sellerController.getStoreByOwnerId(currentUser.id) ?? sellerController.getStoreByEmail(currentUser.email ?? '');
      if (store != null) return true;
    }
    return false;
  }

  AppStore? get activeSellerStore {
    if (_loggedInSellerId != null) {
      final store = sellerController.getStoreById(_loggedInSellerId!);
      if (store != null) return store;
    }
    final currentUser = _safeCurrentUser;
    if (currentUser != null) {
      final store = sellerController.getStoreByOwnerId(currentUser.id) ?? sellerController.getStoreByEmail(currentUser.email ?? '');
      if (store != null) return store;
    }
    return sellerController.activeSellerStore;
  }

  void setLoggedInSellerId(String? id) {
    _loggedInSellerId = id;
    notifyListeners();
  }

  Future<bool> registerSeller({
    required String fullName,
    required String businessName,
    required String storeName,
    required String email,
    required String mobileNumber,
    required String country,
    required String city,
    required String businessAddress,
    required String storeDescription,
    required String storeCategory,
    required String storeSlug,
    required String storeContactNumber,
    required String storeEmail,
    required String storeLogo,
    required String storeBanner,
  }) async {
    final existing = sellerController.getStoreByEmail(email);
    if (existing != null) {
      existing.isApproved = false;
      existing.kycStatus = 'Pending';
      existing.shopName = storeName;
      existing.businessName = businessName;
      existing.fullName = fullName;
      existing.mobileNumber = mobileNumber;
      sellerController.syncAddStorePresentationCache(existing);
      notifyListeners();
      return true;
    }
    final newId = 'seller_${DateTime.now().millisecondsSinceEpoch}';
    final newStore = AppStore(
      id: newId,
      shopName: storeName,
      shopLogo: storeLogo,
      shopBanner: storeBanner,
      shopDescription: storeDescription,
      isApproved: false,
      kycStatus: 'Pending',
      fullName: fullName,
      businessName: businessName,
      email: email,
      mobileNumber: mobileNumber,
      country: country,
      city: city,
      businessAddress: businessAddress,
      storeCategory: storeCategory,
      storeSlug: storeSlug,
      storeContactNumber: storeContactNumber,
      storeEmail: storeEmail,
    );
    sellerController.syncAddStorePresentationCache(newStore);
    _loggedInSellerId = newId;
    notifyListeners();
    return true;
  }

  bool get isCustomerLoggedIn => _safeCurrentUser != null;
  String? get loggedInCustomerName => _safeCurrentUser?.userMetadata?['full_name'] as String? ?? _safeCurrentUser?.email?.split('@').first;
  String? get loggedInCustomerEmail => _safeCurrentUser?.email;
  String? get loggedInCustomerPhone => _safeCurrentUser?.phone;

  // Advanced Customer Preferences
  String _selectedSizePref = 'M';
  String _selectedSkinPref = 'Normal';
  String _selectedDietPref = 'Halal';

  // Budgeting System
  double _monthlyBudgetLimit = 20000.0;
  double _currentBudgetSpent = 3700.0; // initial spent
  final List<String> _budgetWarnings = [];

  // Address Book
  final List<AppAddress> _addresses = [
    AppAddress(
      id: 'addr_1',
      title: 'Home',
      recipientName: 'Ali Khan',
      phone: '03001234567',
      addressLine: 'House Number 12, Street 3',
      city: 'Lahore',
      unionCouncil: 'UC 42',
      landmark: 'Near Central Mosque',
      gateInstructions: 'Leave package with security gate',
      deliverySlot: 'Morning',
    )
  ];

  // Comparison Tray
  final List<String> _comparisonProductIds = [];

  // Customer Wallet
  double _walletCash = 0.0;
  double _walletPromoCredits = 0.0;
  final List<Map<String, dynamic>> _walletTransactions = [];

  // BNPL Credit System
  String _bnplStatus = 'NotApplied'; // 'NotApplied', 'Approved', 'Rejected'
  double _bnplCreditLimit = 0.0;
  double _bnplCreditUsed = 0.0;
  final List<Map<String, dynamic>> _bnplSchedule = [];

  // Categories list with default static fallback
  List<Map<String, String>> _categoriesList = [
    {"name": "Electronics", "image": "https://images.unsplash.com/photo-1498049794561-7780e7231661?w=200&q=80"},
    {"name": "Fashion", "image": "https://images.unsplash.com/photo-1483985988355-763728e1935b?w=200&q=80"},
    {"name": "Mobiles", "image": "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=200&q=80"},
    {"name": "Laptops", "image": "https://images.unsplash.com/photo-1496181130204-755241544eab?w=200&q=80"},
    {"name": "Home & Living", "image": "https://images.unsplash.com/photo-1513694203232-719a280e022f?w=200&q=80"},
    {"name": "Beauty", "image": "https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=200&q=80"},
    {"name": "Groceries", "image": "https://images.unsplash.com/photo-1542838132-92c53300491e?w=200&q=80"},
    {"name": "Sports", "image": "https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=200&q=80"},
    {"name": "Automotive", "image": "https://images.unsplash.com/photo-1607860108855-64acf2078ed9?w=200&q=80"},
    {"name": "Furniture", "image": "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=200&q=80"},
    {"name": "Baby & Toys", "image": "https://images.unsplash.com/photo-1559251606-c623743a6d76?w=200&q=80"},
    {"name": "Health", "image": "https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=200&q=80"},
    {"name": "Books", "image": "https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=200&q=80"},
    {"name": "Watches", "image": "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=200&q=80"},
    {"name": "Pet Supplies", "image": "https://images.unsplash.com/photo-1535268647977-a403b69fc756?w=200&q=80"},
    {"name": "More", "image": "https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=200&q=80"}
  ];

  // Getters
  List<AppStore> get stores => sellerController.stores;
  List<AppProduct> get products => catalogController.products;
  List<AppOrder> get orders => ordersController.orders;
  List<Map<String, String>> get categoriesList => catalogController.categoriesList;
  List<String> get comparisonProductIds => List.unmodifiable(_comparisonProductIds);
  List<AppProduct> get activeProducts => catalogController.activeProducts;

  // Loading & Error States
  bool get isLoadingProducts => catalogController.isLoadingProducts;
  bool _isLoadingCategories = false;
  String? _supabaseError;

  bool get isLoadingCategories => _isLoadingCategories;
  bool get isLoadingStores => sellerController.isLoadingStores;
  bool get isLoadingOrders => ordersController.isLoadingOrders;
  String? get supabaseError => _supabaseError;

  // ----------------------------------------------------
  // SUPABASE LIVE DATA FETCHERS
  // ----------------------------------------------------
  Future<void> fetchAllFromSupabase() async {
    await Future.wait([
      fetchProductsFromSupabase(),
      fetchCategoriesFromSupabase(),
      fetchStoresFromSupabase(),
      fetchOrdersFromSupabase(),
    ]);
  }

  Future<void> fetchProductsFromSupabase() => catalogController.fetchProductsFromSupabase();

  Future<void> fetchCategoriesFromSupabase() => catalogController.fetchCategoriesFromSupabase();

  Future<void> fetchStoresFromSupabase() => sellerController.fetchStoresFromSupabase();

  Future<void> fetchOrdersFromSupabase() => ordersController.fetchOrdersFromSupabase();
  List<String> get announcements => _announcements;
  Map<String, double> get vouchers => _vouchers;

  // Customer Getters
  String get selectedSizePref => _selectedSizePref;
  String get selectedSkinPref => _selectedSkinPref;
  String get selectedDietPref => _selectedDietPref;
  double get monthlyBudgetLimit => _monthlyBudgetLimit;
  double get currentBudgetSpent => _currentBudgetSpent;
  List<String> get budgetWarnings => _budgetWarnings;
  List<AppAddress> get addresses => _addresses;
  double get walletCash => _walletCash;
  double get walletPromoCredits => _walletPromoCredits;
  List<Map<String, dynamic>> get walletTransactions => _walletTransactions;
  String get bnplStatus => _bnplStatus;
  double get bnplCreditLimit => _bnplCreditLimit;
  double get bnplCreditUsed => _bnplCreditUsed;
  int get wishlistCount => cartController.wishlistProducts.length;

  bool _isStoreOnVacation(String sellerId) {
    final store = sellerController.getStoreById(sellerId);
    return store?.isVacationMode ?? false;
  }

  void saveStoresToLocalStorage() => sellerController.saveStoresToLocalStorage();

  void loadStoresFromLocalStorage() => sellerController.loadStoresFromLocalStorage();

  void saveProductsToLocalStorage() => catalogController.saveProductsToLocalStorage();

  void loadProductsFromLocalStorage() => catalogController.loadProductsFromLocalStorage();



  // 1. Initialize Cache
  void _initializeLocalCache() {
    loadStoresFromLocalStorage();
    loadProductsFromLocalStorage();
  }

  // ==========================================
  // CUSTOMER STATE MUTATIONS
  // ==========================================

  void updatePreferences(String size, String skin, String diet) {
    _selectedSizePref = size;
    _selectedSkinPref = skin;
    _selectedDietPref = diet;
    notifyListeners();
  }

  void setBudgetLimit(double limit) {
    _monthlyBudgetLimit = limit;
    _checkBudget();
    notifyListeners();
  }

  void _checkBudget() {
    if (_currentBudgetSpent > _monthlyBudgetLimit) {
      _budgetWarnings.add(':       (${_currentBudgetSpent.toInt()} PKR)     Budget (${_monthlyBudgetLimit.toInt()} PKR)    !');
    }
  }



  void addAddress(AppAddress address) {
    if (address.isDefault || _addresses.isEmpty) {
      for (var a in _addresses) {
        a.isDefault = false;
      }
      address.isDefault = true;
    }
    _addresses.add(address);
    notifyListeners();
  }

  void editAddress(String id, AppAddress updated) {
    final idx = _addresses.indexWhere((a) => a.id == id);
    if (idx != -1) {
      if (updated.isDefault) {
        for (var a in _addresses) {
          a.isDefault = false;
        }
      }
      _addresses[idx] = updated;
      notifyListeners();
    }
  }

  void deleteAddress(String id) {
    _addresses.removeWhere((a) => a.id == id);
    if (_addresses.isNotEmpty && !_addresses.any((a) => a.isDefault)) {
      _addresses.first.isDefault = true;
    }
    notifyListeners();
  }

  void setDefaultAddress(String id) {
    for (var a in _addresses) {
      a.isDefault = (a.id == id);
    }
    notifyListeners();
  }

  void toggleComparison(String productId) {
    if (_comparisonProductIds.contains(productId)) {
      _comparisonProductIds.remove(productId);
    } else {
      if (_comparisonProductIds.length < 3) {
        _comparisonProductIds.add(productId);
      }
    }
    notifyListeners();
  }

  void clearComparison() {
    _comparisonProductIds.clear();
    notifyListeners();
  }

  List<double> getPriceHistory(String productId) => catalogController.getPriceHistory(productId);

  void addWalletTransaction(String desc, double amount, String type) {
    if (type == 'Cash') {
      _walletCash += amount;
    } else {
      _walletPromoCredits += amount;
    }
    _walletTransactions.insert(0, {
      'date': '',
      'desc': desc,
      'amount': amount,
      'type': type,
    });
    notifyListeners();
  }

  void applyForBnpl() {
    _bnplStatus = 'Approved';
    notifyListeners();
  }

  void chargeBnpl(double amount, int months) {
    _bnplCreditUsed += amount;
    final double monthlyInstallment = amount / months;
    _bnplSchedule.clear();
    for (int i = 1; i <= months; i++) {
      _bnplSchedule.add({
        'dueDate': 'Month $i',
        'amount': monthlyInstallment,
        'status': 'Unpaid',
      });
    }
    _currentBudgetSpent += amount;
    _checkBudget();
    notifyListeners();
  }

  // ==========================================
  // SELLER PORTAL MUTATIONS & DATA CLEARING
  // ==========================================


  // Clear products & orders cache for specific seller store
  void clearProductsForStore(String sellerId) {
    catalogController.clearProductsForStore(sellerId);
    ordersController.clearOrdersForSeller(sellerId);
    notifyListeners();
  }

  // Toggle Vacation Mode
  void setVacationMode(String sellerId, bool status) => sellerController.setVacationMode(sellerId, status);

  // Update Store Profile Details
  Future<void> updateStoreProfile(String storeId, String name, String desc, String logo, String banner) =>
      sellerController.updateStoreProfile(storeId, name, desc, logo, banner);

  // Submit KYC Documents
  void submitKyc(String sellerId, String cnic, String ntn) {
    final store = sellerController.getStoreById(sellerId);
    if (store != null) {
      store.kycStatus = 'Pending';
      notifyListeners();
    }
  }

  // Add a new product (via canonical ProductRepository and sync presentation cache)
  Future<void> addProduct(AppProduct product) async {
    catalogController.syncAddProductCache(product);
    await ProductRepository().createProduct(product.toJson());
  }

  // Add a new Category (via canonical ProductRepository and sync presentation cache)
  Future<void> addCategory(String name, String image) async {
    catalogController.syncAddCategoryCache(name, image);
    await ProductRepository().createCategory(name, image);
  }

  // Update Stock via canonical ProductRepository (Phase 8 RPC seller_update_product_stock)
  Future<void> adjustStock(String productId, int newStock) async {
    final idx = products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      products[idx].stock = newStock;
      catalogController.saveProductsToLocalStorage();
      notifyListeners();
    }
    await ProductRepository().updateProductStock(productId, newStock);
  }

  // Order state transition via Phase 11 RPC seller_update_fulfillment_status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    ordersController.syncUpdateOrderStatusCache(orderId, newStatus);
    await SupabaseOrdersService().updateFulfillmentStatus(
      orderId: orderId,
      newStatus: newStatus == 'Confirmed' ? 'Processing' : newStatus,
    );
  }

  // Create Vouchers
  final SupabaseVoucherService _voucherService = SupabaseVoucherService();

  Future<VoucherValidationResult> validateVoucherOnline({
    required String code,
    required double subtotal,
  }) async {
    final result = await _voucherService.validateVoucher(code: code, subtotal: subtotal);
    if (result.isValid) {
      _vouchers[result.code ?? code.toUpperCase()] = result.discountAmount;
      notifyListeners();
    }
    return result;
  }

  void addVoucher(String code, double discount) {
    _vouchers[code] = discount;
    notifyListeners();
  }

  // ==========================================
  // BUYER PORTAL MUTATIONS
  // ==========================================

  // Follow Shop
  void followShop(String sellerId) => sellerController.followShop(sellerId);

  // Place Order (Delegates to server-authoritative SupabaseCheckoutService RPC)
  Future<void> placeOrder({
    required String productId,
    required String sellerId,
    required String buyerName,
    required String address,
    required String shippingSpeed,
    required String paymentMethod,
    required double couponDiscount,
  }) async {
    final String idempotencyKey = 'po_${DateTime.now().millisecondsSinceEpoch}_$productId';

    final res = await SupabaseCheckoutService().checkout(
      idempotencyKey: idempotencyKey,
      items: [
        {'product_id': productId, 'quantity': 1}
      ],
      shippingAddress: {
        'recipient_name': buyerName,
        'address_line': address,
      },
      paymentMethod: paymentMethod,
    );

    final String orderNumber = (res['order_number'] ?? '').toString();
    final double grandTotal = (res['grand_total'] is num) ? (res['grand_total'] as num).toDouble() : 0.0;

    final prodIdx = products.indexWhere((p) => p.id == productId);
    final product = prodIdx != -1 ? products[prodIdx] : null;

    final newOrder = AppOrder(
      id: orderNumber,
      productId: productId,
      productName: product?.name ?? 'Marketplace Item',
      productPrice: product != null ? double.tryParse(product.price) ?? 0.0 : 0.0,
      sellerId: sellerId,
      buyerName: buyerName,
      shippingAddress: address,
      shippingSpeed: shippingSpeed,
      paymentMethod: paymentMethod,
      couponDiscount: couponDiscount,
      commissionDeducted: 0.0,
      finalPayout: grandTotal,
      orderStatus: 'Pending',
      trackingNumber: 'TRK${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );

    ordersController.syncAddOrderPresentationCache(newOrder);
    await ordersController.fetchOrdersFromSupabase();
  }

  // Request Return
  void requestReturn(String orderId, String reason) {
    final order = ordersController.getOrderById(orderId);
    if (order != null) {
      ordersController.syncUpdateReturnStatusCache(orderId, reason, 'Pending');
      notifyListeners();
    }
  }

  // Submit Product Review

  // ==========================================
  // CHAT & COMMUNICATIONS
  // ==========================================

  List<ChatMessage> getChatroom(String buyerName, String sellerId) {
    final String key = '${buyerName}_$sellerId';
    return _chats[key] ?? [];
  }

  void sendMessage(String buyerName, String sellerId, String message, String sender) {
    final String key = '${buyerName}_$sellerId';
    if (!_chats.containsKey(key)) {
      _chats[key] = [];
    }

    _chats[key]!.add(ChatMessage(
      sender: sender,
      message: message,
      timestamp: DateTime.now(),
    ));

    notifyListeners();
  }

  SupabaseClient? get _safeSupabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // SUPER ADMIN MUTATIONS
  // ==========================================

  // Approve Store
  Future<void> approveStore(String storeId, {double? commissionRate}) async {
    final store = sellerController.getStoreById(storeId);
    if (store != null) {
      store.isApproved = true;
      store.kycStatus = 'Approved';
      if (commissionRate != null) store.commissionRate = commissionRate;
      notifyListeners();
    }

    try {
      final client = _safeSupabase;
      if (client != null && !storeId.startsWith('seller_')) {
        await client.rpc('admin_review_seller_store', params: {
          'target_store_id': storeId,
          'approve': true,
          'new_commission': commissionRate,
        });
      }
    } catch (e) {
      debugPrint('Supabase approveStore RPC error: $e');
      rethrow;
    }
  }

  // Reject Store
  Future<void> rejectStore(String storeId, String reason) async {
    final store = sellerController.getStoreById(storeId);
    if (store != null) {
      store.isApproved = false;
      store.kycStatus = 'Rejected';
      store.rejectionReason = reason;
      notifyListeners();
    }

    try {
      final client = _safeSupabase;
      if (client != null && !storeId.startsWith('seller_')) {
        await client.rpc('admin_review_seller_store', params: {
          'target_store_id': storeId,
          'approve': false,
          'new_commission': null,
        });
      }
    } catch (e) {
      debugPrint('Supabase rejectStore RPC error: $e');
      rethrow;
    }
  }

  // Update Custom Commission Rate
  Future<void> adjustCommission(String storeId, double rate) async {
    final store = sellerController.getStoreById(storeId);
    if (store != null) {
      store.commissionRate = rate;
      notifyListeners();
    }

    try {
      final client = _safeSupabase;
      if (client != null && !storeId.startsWith('seller_')) {
        await client.rpc('admin_review_seller_store', params: {
          'target_store_id': storeId,
          'approve': store?.isApproved ?? true,
          'new_commission': rate,
        });
      }
    } catch (e) {
      debugPrint('Supabase adjustCommission RPC error: $e');
      rethrow;
    }
  }

  // Approve Product Listing
  Future<void> approveProduct(String productId) async {
    final idx = products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      products[idx].approvalStatus = 'Approved';
      notifyListeners();
    }

    try {
      final client = _safeSupabase;
      if (client != null) {
        await client.rpc('admin_review_product', params: {
          'target_product_id': productId,
          'approve': true,
        });
      }
    } catch (e) {
      debugPrint('Supabase approveProduct RPC error: $e');
      rethrow;
    }
  }

  // Reject Product Listing
  Future<void> rejectProduct(String productId, String reason) async {
    final idx = products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      products[idx].approvalStatus = 'Rejected';
      products[idx].rejectionReason = reason;
      notifyListeners();
    }

    try {
      final client = _safeSupabase;
      if (client != null) {
        await client.rpc('admin_review_product', params: {
          'target_product_id': productId,
          'approve': false,
        });
      }
    } catch (e) {
      debugPrint('Supabase rejectProduct RPC error: $e');
      rethrow;
    }
  }

  void rateProduct(String productId, String rating) {
    final idx = products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      products[idx].rating = rating;
      catalogController.saveProductsToLocalStorage();
      notifyListeners();
    }
  }

  // Broadcast platform-wide message
  void broadcastAnnouncement(String message) {
    _announcements.insert(0, message);
    notifyListeners();
  }

  // Resolve Return Disputes
  void arbitrateDispute(String orderId, String resolution) {
    final order = ordersController.getOrderById(orderId);
    if (order != null) {
      order.disputeStatus = 'Resolved';
      notifyListeners();
    }
  }

  // Payout Settled Ledger
  void triggerPayout(String storeId) {
    final store = sellerController.getStoreById(storeId);
    if (store != null) {
      store.lastPayout = store.balance;
      store.balance = 0.0;
      notifyListeners();
    }
  }

  // --- CART & WISHLIST METHODS ---
  void addToCart(AppProduct product, {int quantity = 1}) => cartController.addToCart(product, quantity: quantity);

  void removeFromCart(String productId) => cartController.removeFromCart(productId);

  void removeSingleFromCart(String productId) => cartController.removeSingleFromCart(productId);

  void clearCart() => cartController.clearCart();

  bool isProductWishlisted(String productId) => cartController.isProductWishlisted(productId);

  bool isInWishlist(String productId) => cartController.isProductWishlisted(productId);

  void toggleWishlist(AppProduct product) => cartController.toggleWishlist(product);

  void removeFromWishlist(String productId) => cartController.removeFromWishlist(productId);

  void clearWishlist() => cartController.clearWishlist();
}
