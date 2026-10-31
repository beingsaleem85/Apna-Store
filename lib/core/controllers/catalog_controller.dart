import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/app_state_provider.dart';
import '../services/product_repository.dart';
import '../utils/web_helper.dart';

class CatalogController extends ChangeNotifier {
  final List<AppProduct> _products = [];
  List<Map<String, dynamic>> _categoriesList = [
    {"name": "Electronics", "image": "https://images.unsplash.com/photo-1498049794561-7780e7231661?w=200&q=80"},
    {"name": "Fashion", "image": "https://images.unsplash.com/photo-1483985988355-763728e1935b?w=200&q=80"},
    {"name": "Mobiles", "image": "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=200&q=80"},
    {"name": "Laptops", "image": "https://images.unsplash.com/photo-1496181130204-755241544eab?w=200&q=80"},
    {"name": "Home & Living", "image": "https://images.unsplash.com/photo-1513694203232-719a280e022f?w=200&q=80"},
    {"name": "Beauty", "image": "https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=200&q=80"},
    {"name": "Groceries", "image": "https://images.unsplash.com/photo-1542838132-92c53300491e?w=200&q=80"},
    {"name": "Sports", "image": "https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=200&q=80"},
  ];
  bool _isLoadingProducts = false;
  final ProductRepository _productRepository;

  String? _productsError;

  CatalogController({ProductRepository? productRepository})
      : _productRepository = productRepository ?? ProductRepository();

  List<AppProduct> get products => List.unmodifiable(_products);
  List<Map<String, String>> get categoriesList {
    return List.unmodifiable(_categoriesList.map((item) => {
          "name": (item['name'] ?? '').toString(),
          "image": (item['image'] ?? '').toString(),
        }));
  }
  bool get isLoadingProducts => _isLoadingProducts;
  String? get productsError => _productsError;

  List<AppProduct> get activeProducts => _products
      .where((p) => p.approvalStatus.toLowerCase() == 'approved' || p.approvalStatus.toLowerCase() == 'active')
      .toList();

  Future<void> initialize() async {
    await initializeCatalog();
  }

  Future<void> initializeCatalog() async {
    await Future.wait([
      fetchProductsFromSupabase(),
      fetchCategoriesFromSupabase(),
    ]);
  }

  Future<void> fetchProductsFromSupabase() async {
    _isLoadingProducts = true;
    _productsError = null;
    notifyListeners();

    try {
      final response = await _productRepository.fetchProducts();
      _products.clear();
      for (var item in response) {
        _products.add(AppProduct.fromJson(Map<String, dynamic>.from(item)));
      }
      saveProductsToLocalStorage();
    } catch (e) {
      debugPrint('ProductRepository fetch products error: $e');
      _productsError = e.toString();
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> fetchCategoriesFromSupabase() async {
    try {
      final response = await _productRepository.fetchCategories();
      _categoriesList = List<Map<String, dynamic>>.from(response)
          .map((item) => {
                "name": (item['name'] ?? '').toString(),
                "image": (item['image'] ?? '').toString(),
              })
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('ProductRepository fetch categories error: $e');
    }
  }

  void saveProductsToLocalStorage() {
    try {
      final data = jsonEncode(_products.map((p) => p.toJson()).toList());
      WebHelper.setLocalStorage('apna_products_persistent', data);
    } catch (e) {
      debugPrint('Error saving products to localStorage: $e');
    }
  }

  void loadProductsFromLocalStorage() {
    try {
      final data = WebHelper.getLocalStorage('apna_products_persistent');
      if (data != null && data.isNotEmpty) {
        final List<dynamic> parsed = jsonDecode(data);
        final loadedProducts = parsed.map((item) => AppProduct.fromJson(item)).toList();
        _products.clear();
        _products.addAll(loadedProducts);
      }
    } catch (e) {
      debugPrint('Error loading products from localStorage: $e');
    }
    notifyListeners();
  }

  void clearAllProducts() {
    _products.clear();
    saveProductsToLocalStorage();
    notifyListeners();
  }

  void clearProductsForStore(String sellerId) {
    _products.removeWhere((p) => p.sellerId == sellerId);
    saveProductsToLocalStorage();
    notifyListeners();
  }

  /// PRESENTATION CACHE SYNC ONLY
  /// Updates local presentation cache after canonical backend product creation success.
  Future<void> syncAddProductCache(AppProduct product) async {
    _products.add(product);
    saveProductsToLocalStorage();
    notifyListeners();
  }

  /// PRESENTATION CACHE SYNC ONLY
  /// Updates local presentation cache after canonical backend category creation success.
  Future<void> syncAddCategoryCache(String name, String image) async {
    _categoriesList.add({"name": name, "image": image});
    notifyListeners();
  }

  /// Presentation cache sync alias for compatibility.
  Future<void> addProduct(AppProduct product) => syncAddProductCache(product);

  /// Presentation cache sync alias for compatibility.
  Future<void> addCategory(String name, String image) => syncAddCategoryCache(name, image);

  List<double> getPriceHistory(String productId) {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final basePrice = double.tryParse(_products[idx].price.replaceAll(',', '')) ?? 0.0;
      if (basePrice > 0) {
        return [basePrice];
      }
    }
    return [];
  }
}
