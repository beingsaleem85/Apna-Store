import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_state_provider.dart';
import '../services/supabase_seller_service.dart';
import 'package:apna_store/core/utils/web_helper.dart';

class SellerController extends ChangeNotifier {
  final List<AppStore> _stores = [];
  String? _activeSellerStoreId;
  bool _isLoadingStores = false;
  String? _storesError;
  final SupabaseSellerService _supabaseSellerService;

  SellerController({SupabaseSellerService? supabaseSellerService})
      : _supabaseSellerService = supabaseSellerService ?? SupabaseSellerService() {
    _initStores();
  }

  List<AppStore> get stores => List.unmodifiable(_stores);
  bool get isLoadingStores => _isLoadingStores;
  String? get storesError => _storesError;
  String? get activeSellerStoreId => _activeSellerStoreId;

  static const Set<String> protectedFields = {
    'owner_id',
    'user_id',
    'is_approved',
    'is_verified',
    'is_suspended',
    'kyc_status',
    'commission_rate',
    'balance',
    'pending_payout',
    'last_payout',
    'payout_locked',
    'role',
    'admin',
  };

  AppStore? get activeSellerStore {
    if (_activeSellerStoreId != null) {
      final idx = _stores.indexWhere((s) => s.id == _activeSellerStoreId);
      if (idx != -1) return _stores[idx];
    }
    return _stores.isNotEmpty ? _stores.first : null;
  }

  void _initStores() {
    loadStoresFromLocalStorage();
    fetchStoresFromSupabase();
  }

  void setActiveSellerStoreId(String? id) {
    _activeSellerStoreId = id;
    notifyListeners();
  }

  AppStore? getStoreById(String storeId) {
    final idx = _stores.indexWhere((s) => s.id == storeId);
    return idx != -1 ? _stores[idx] : null;
  }

  AppStore? getStoreBySellerId(String sellerId) {
    final idx = _stores.indexWhere((s) => s.id == sellerId);
    return idx != -1 ? _stores[idx] : null;
  }

  AppStore? getStoreByEmail(String email) {
    final idx = _stores.indexWhere((s) => s.email == email);
    return idx != -1 ? _stores[idx] : null;
  }

  AppStore? getStoreByOwnerId(String ownerId) {
    final idx = _stores.indexWhere((s) => s.ownerId == ownerId || s.id == ownerId);
    return idx != -1 ? _stores[idx] : null;
  }

  Future<void> fetchStoresFromSupabase() async {
    _isLoadingStores = true;
    _storesError = null;
    notifyListeners();

    try {
      final response = await _supabaseSellerService.fetchAllStores();
      if (response.isNotEmpty) {
        _stores.clear();
        for (var item in response) {
          _stores.add(AppStore.fromJson(Map<String, dynamic>.from(item)));
        }
        saveStoresToLocalStorage();
      }
    } catch (e) {
      debugPrint('SupabaseSellerService fetchAllStores error: $e');
      if (!e.toString().contains('_isInitialized')) {
        _storesError = e.toString();
      }
    } finally {
      _isLoadingStores = false;
      notifyListeners();
    }
  }

  void syncAddStorePresentationCache(AppStore store) {
    final existingIdx = _stores.indexWhere((s) => s.id == store.id);
    if (existingIdx != -1) {
      _stores[existingIdx] = store;
    } else {
      _stores.add(store);
    }
    saveStoresToLocalStorage();
    notifyListeners();
  }

  void setVacationMode(String storeId, bool status) {
    final idx = _stores.indexWhere((s) => s.id == storeId);
    if (idx != -1) {
      _stores[idx].isVacationMode = status;
      saveStoresToLocalStorage();
      notifyListeners();
    }
  }

  void followShop(String storeId) {
    final idx = _stores.indexWhere((s) => s.id == storeId);
    if (idx != -1) {
      _stores[idx].followersCount += 1;
      saveStoresToLocalStorage();
      notifyListeners();
    }
  }

  Future<void> updateStoreProfile(
    String storeId,
    String name,
    String desc,
    String logo,
    String banner,
  ) async {
    final idx = _stores.indexWhere((s) => s.id == storeId);
    if (idx == -1) return;

    final updateMap = <String, dynamic>{
      'shop_name': name,
      'shop_description': desc,
    };
    if (logo.isNotEmpty) updateMap['shop_logo'] = logo;
    if (banner.isNotEmpty) updateMap['shop_banner'] = banner;

    // Verify protected fields are excluded
    for (final key in updateMap.keys) {
      if (protectedFields.contains(key)) {
        throw ArgumentError('Protected field $key cannot be updated via store profile');
      }
    }

    try {
      await _supabaseSellerService.updateStoreDetails(
        storeId: storeId,
        updates: updateMap,
      );

      // On backend success, sync presentation cache
      final store = _stores[idx];
      store.shopName = name;
      store.shopDescription = desc;
      if (logo.isNotEmpty) store.shopLogo = logo;
      if (banner.isNotEmpty) store.shopBanner = banner;
      saveStoresToLocalStorage();
      notifyListeners();
    } catch (e) {
      debugPrint('SupabaseSellerService updateStoreDetails error: $e');
      _storesError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearStoresCache() {
    _stores.clear();
    saveStoresToLocalStorage();
    notifyListeners();
  }

  void saveStoresToLocalStorage() {
    if (kIsWeb) {
      try {
        final data = jsonEncode(_stores.map((s) => s.toJson()).toList());
        WebHelper.setLocalStorage('apna_stores_persistent', data);
      } catch (e) {
        debugPrint('Error saving stores to localStorage: $e');
      }
    }
  }

  void loadStoresFromLocalStorage() {
    if (kIsWeb) {
      try {
        final data = WebHelper.getLocalStorage('apna_stores_persistent');
        if (data != null && data.isNotEmpty) {
          final List<dynamic> parsed = jsonDecode(data);
          final loadedStores = parsed.map((item) => AppStore.fromJson(item)).toList();
          if (loadedStores.isNotEmpty) {
            _stores.clear();
            _stores.addAll(loadedStores);
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Error loading stores from localStorage: $e');
      }
    }
  }
}
