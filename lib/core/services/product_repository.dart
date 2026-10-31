import 'package:supabase_flutter/supabase_flutter.dart';
import '../errors/failures.dart';
import '../models/dtos/product_dto.dart';

class ProductRepository {
  final SupabaseClient? _injected;

  ProductRepository({SupabaseClient? client}) : _injected = client;

  SupabaseClient? get _client {
    if (_injected != null) return _injected;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Update product stock via canonical Phase 8 RPC seller_update_product_stock
  Future<void> updateProductStock(String productId, int newStock) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.rpc('seller_update_product_stock', params: {
        'p_product_id': productId,
        'p_new_stock': newStock,
      });
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Create product via canonical backend database insert
  Future<void> createProduct(Map<String, dynamic> productMap) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('products').insert(productMap);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Update product via canonical backend database update
  Future<void> updateProduct(String productId, Map<String, dynamic> updateMap) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('products').update(updateMap).eq('id', productId);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Soft delete / deactivate product
  Future<void> deactivateProduct(String productId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('products').update({'is_active': false}).eq('id', productId);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Create category via canonical backend database insert
  Future<void> createCategory(String name, String image) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('categories').insert({
        'name': name,
        'image': image,
      });
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Fetch all active & approved products for storefront
  Future<List<Map<String, dynamic>>> fetchApprovedProducts() async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client
          .from('products')
          .select('*')
          .eq('approval_status', 'Approved')
          .eq('is_active', true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Fetch all products via canonical backend database query
  Future<List<Map<String, dynamic>>> fetchProducts() async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client.from('products').select('*');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Fetch products for a specific seller store
  Future<List<Map<String, dynamic>>> fetchSellerProducts(String sellerStoreId) async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client
          .from('products')
          .select('*')
          .eq('seller_store_id', sellerStoreId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Fetch all categories via canonical backend database query
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client.from('categories').select('name, image');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Function to load products based on category name safely.
  Future<List<ProductDto>> fetchProductsByCategory(String categoryName) async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client
          .from('products')
          .select('*')
          .eq('category', categoryName)
          .eq('approval_status', 'Approved')
          .eq('is_active', true);

      final List dataList = response as List;
      return dataList.map((item) => ProductDto.fromDatabaseMap(item as Map<String, dynamic>)).toList();
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }
}
