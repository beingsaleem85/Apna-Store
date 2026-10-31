import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../errors/failures.dart';
import '../models/dtos/product_dto.dart';
import '../models/dtos/seller_store_dto.dart';

class SupabaseSellerService extends ChangeNotifier {
  final SupabaseClient? _injected;
  SupabaseClient? get _safeSupabase {
    if (_injected != null) return _injected;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _supabase => _safeSupabase ?? Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;

  SupabaseSellerService({SupabaseClient? client}) : _injected = client;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentAuthUser => _safeSupabase?.auth.currentUser;

  // ----------------------------------------------------
  // 1. SELLER REGISTRATION WITH SUPABASE
  // ----------------------------------------------------
  Future<SellerStoreDto> registerSeller({
    required String email,
    required String password,
    required String fullName,
    required String businessName,
    required String storeName,
    required String storeSlug,
    required String mobileNumber,
    required String country,
    required String city,
    required String businessAddress,
    required String category,
    required String shopDescription,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step A: Supabase Auth SignUp
      final AuthResponse authRes = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'store_name': storeName,
        },
      );

      final user = authRes.user;
      if (user == null) {
        throw const ValidationFailure(message: 'Signup failed. User object returned null.');
      }

      // Step B: Insert into 'profiles' table
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
        'email': email,
        'mobile_number': mobileNumber,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Step C: Insert into 'seller_stores' table using SellerStoreDto (EXCLUDES password)
      final storeDto = SellerStoreDto(
        id: user.id,
        userId: user.id,
        shopName: storeName,
        shopSlug: storeSlug,
        businessName: businessName,
        businessAddress: businessAddress,
        city: city,
        country: country,
        category: category,
        shopDescription: shopDescription,
        isApproved: false,
        kycStatus: 'Pending',
        createdAt: DateTime.now(),
      );

      final storeData = await _supabase.from('seller_stores').insert(storeDto.toDatabaseMap()).select().single();

      _isLoading = false;
      notifyListeners();
      return SellerStoreDto.fromDatabaseMap(storeData);
    } catch (e, st) {
      if (!AppConfig.isProduction) {
        _isLoading = false;
        notifyListeners();
        return SellerStoreDto(
          id: 'seller_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'dev_user_${DateTime.now().millisecondsSinceEpoch}',
          shopName: storeName,
          shopSlug: storeSlug,
          businessName: businessName,
          businessAddress: businessAddress,
          city: city,
          country: country,
          category: category,
          shopDescription: shopDescription,
          isApproved: false,
          kycStatus: 'Pending',
          createdAt: DateTime.now(),
        );
      }

      _isLoading = false;
      final failure = FailureMapper.mapException(e, st);
      _errorMessage = failure.message;
      notifyListeners();
      throw failure;
    }
  }

  // ----------------------------------------------------
  // 2. SELLER LOGIN WITH SUPABASE
  // ----------------------------------------------------
  Future<SellerStoreDto?> loginSeller({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final AuthResponse authRes = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = authRes.user;
      if (user == null) {
        throw const AuthenticationFailure(message: 'Login failed. User object returned null.');
      }

      final storeData = await _supabase
          .from('seller_stores')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      _isLoading = false;
      notifyListeners();
      return storeData != null ? SellerStoreDto.fromDatabaseMap(storeData) : null;
    } catch (e, st) {
      _isLoading = false;
      final failure = FailureMapper.mapException(e, st);
      _errorMessage = failure.message;
      notifyListeners();
      throw failure;
    }
  }

  // ----------------------------------------------------
  // 3. FETCH ALL SELLER STORES / FETCH BY USER ID
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchAllStores() async {
    final client = _safeSupabase;
    if (client == null) return [];
    try {
      final response = await client.from('seller_stores').select('*');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  Future<SellerStoreDto?> fetchStoreByUserId(String userId) async {
    final client = _safeSupabase;
    if (client == null) return null;
    try {
      final storeData = await client
          .from('seller_stores')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return storeData != null ? SellerStoreDto.fromDatabaseMap(storeData) : null;
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  // ----------------------------------------------------
  // 4. UPDATE SELLER STORE DETAILS
  // ----------------------------------------------------
  Future<bool> updateStoreDetails({
    required String storeId,
    required Map<String, dynamic> updates,
  }) async {
    final client = _safeSupabase;
    if (client == null) return true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dbUpdates = Map<String, dynamic>.from(updates);
      if (dbUpdates.containsKey('shop_logo_path')) {
        dbUpdates['shop_logo'] = dbUpdates.remove('shop_logo_path');
      }
      if (dbUpdates.containsKey('shop_banner_path')) {
        dbUpdates['shop_banner'] = dbUpdates.remove('shop_banner_path');
      }
      dbUpdates['updated_at'] = DateTime.now().toIso8601String();

      await client.from('seller_stores').update(dbUpdates).eq('id', storeId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _isLoading = false;
      final failure = FailureMapper.mapException(e, st);
      _errorMessage = failure.message;
      notifyListeners();
      throw failure;
    }
  }

  // ----------------------------------------------------
  // 5. UPLOAD STORE ASSETS & KYC TO SUPABASE STORAGE
  // ----------------------------------------------------

  /// Upload private KYC document into private 'kyc-documents' bucket under owner folder
  Future<String> uploadPrivateKycDocument({
    required String ownerId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    try {
      final path = '$ownerId/$fileName';
      await _supabase.storage.from('kyc-documents').uploadBinary(
        path,
        fileBytes,
        fileOptions: const FileOptions(upsert: true),
      );
      return path;
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Get time-limited signed URL (valid for 60 minutes) for authorized KYC document viewing
  Future<String> getSignedKycUrl(String path, {int expiresInSeconds = 3600}) async {
    try {
      final signedUrl = await _supabase.storage
          .from('kyc-documents')
          .createSignedUrl(path, expiresInSeconds);
      return signedUrl;
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Upload public store media (Logo / Banner) into 'seller-store-media' bucket
  Future<String> uploadStoreMedia({
    required String ownerId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    try {
      final path = '$ownerId/$fileName';
      await _supabase.storage.from('seller-store-media').uploadBinary(
        path,
        fileBytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final publicUrl = _supabase.storage.from('seller-store-media').getPublicUrl(path);
      return publicUrl;
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  Future<String?> uploadStoreAsset({
    required String storeId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    try {
      final path = 'stores/$storeId/$fileName';
      await _supabase.storage.from('seller-store-media').uploadBinary(
        path,
        fileBytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = _supabase.storage.from('seller-store-media').getPublicUrl(path);
      return publicUrl;
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  // ----------------------------------------------------
  // 6. PASSWORD RESET REQUEST
  // ----------------------------------------------------
  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  // ----------------------------------------------------
  // 7. SELLER LOGOUT
  // ----------------------------------------------------
  Future<void> logoutSeller() async {
    try {
      await _supabase.auth.signOut();
      notifyListeners();
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  // ----------------------------------------------------
  // 8. PRODUCT MANAGEMENT (CRUD)
  // ----------------------------------------------------
  Future<void> addProduct(ProductDto productDto) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase.from('products').insert(productDto.toInsertMap());
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      _isLoading = false;
      final failure = FailureMapper.mapException(e, st);
      _errorMessage = failure.message;
      notifyListeners();
      throw failure;
    }
  }

  Future<void> editProduct({required String productId, required ProductDto productDto}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase
          .from('products')
          .update(productDto.toUpdateMap())
          .eq('id', productId);
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      _isLoading = false;
      final failure = FailureMapper.mapException(e, st);
      _errorMessage = failure.message;
      notifyListeners();
      throw failure;
    }
  }

  Future<void> deleteProduct(String productId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase
          .from('products')
          .update({'is_active': false})
          .eq('id', productId);
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      _isLoading = false;
      final failure = FailureMapper.mapException(e, st);
      _errorMessage = failure.message;
      notifyListeners();
      throw failure;
    }
  }

  // ----------------------------------------------------
  // 9. ADMIN GOVERNANCE & MODERATION RPCS
  // ----------------------------------------------------
  Future<bool> adminReviewSellerStore({
    required String storeId,
    required bool approve,
    double? commissionRate,
  }) async {
    try {
      final res = await _supabase.rpc('admin_review_seller_store', params: {
        'target_store_id': storeId,
        'approve': approve,
        'new_commission': commissionRate,
      });
      return res == true;
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  Future<bool> adminReviewProduct({
    required String productId,
    required bool approve,
  }) async {
    try {
      final res = await _supabase.rpc('admin_review_product', params: {
        'target_product_id': productId,
        'approve': approve,
      });
      return res == true;
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  Future<bool> adminReviewKycDocument({
    required String kycId,
    required String status,
    String? reason,
  }) async {
    try {
      final res = await _supabase.rpc('admin_review_kyc_document', params: {
        'target_kyc_id': kycId,
        'new_status': status,
        'reason': reason,
      });
      return res == true;
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  Future<Map<String, dynamic>> adminToggleSellerSuspension({
    required String storeId,
    required bool isSuspended,
  }) async {
    try {
      final res = await _supabase.rpc('admin_toggle_seller_suspension', params: {
        'p_store_id': storeId,
        'p_is_suspended': isSuspended,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  Future<Map<String, dynamic>> adminTogglePayoutLock({
    required String storeId,
    required bool isLocked,
  }) async {
    try {
      final res = await _supabase.rpc('admin_toggle_payout_lock', params: {
        'p_store_id': storeId,
        'p_is_locked': isLocked,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  // ----------------------------------------------------
  // 10. PAYOUTS & FINANCIAL LEDGER
  // ----------------------------------------------------
  Future<Map<String, dynamic>> requestSellerPayout({
    required String storeId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountTitle,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _supabase.rpc('seller_request_payout', params: {
        'p_store_id': storeId,
        'p_amount': amount,
        'p_bank_name': bankName,
        'p_account_number': accountNumber,
        'p_account_title': accountTitle,
      });
      _isLoading = false;
      notifyListeners();
      return Map<String, dynamic>.from(res as Map);
    } catch (e, st) {
      _isLoading = false;
      final failure = FailureMapper.mapException(e, st);
      _errorMessage = failure.message;
      notifyListeners();
      throw failure;
    }
  }

  Future<Map<String, dynamic>> adminProcessPayout({
    required String payoutId,
    required String action,
    String? reason,
    String? reference,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _supabase.rpc('admin_process_payout', params: {
        'p_payout_id': payoutId,
        'p_action': action,
        'p_reason': reason,
        'p_reference': reference,
      });
      _isLoading = false;
      notifyListeners();
      return Map<String, dynamic>.from(res as Map);
    } catch (e, st) {
      _isLoading = false;
      final failure = FailureMapper.mapException(e, st);
      _errorMessage = failure.message;
      notifyListeners();
      throw failure;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPayoutRequests({String? storeId}) async {
    try {
      var query = _supabase.from('seller_payout_requests').select('*');
      if (storeId != null) {
        query = query.eq('seller_store_id', storeId);
      }
      final res = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }

  Future<List<Map<String, dynamic>>> fetchKycDocuments({String? storeId}) async {
    try {
      var query = _supabase.from('seller_kyc_documents').select('*');
      if (storeId != null) {
        query = query.eq('seller_store_id', storeId);
      }
      final res = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }
}
