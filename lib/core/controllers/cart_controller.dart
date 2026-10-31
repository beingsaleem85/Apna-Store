import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_state_provider.dart'; // For AppProduct

class CartController extends ChangeNotifier {
  final List<AppProduct> _cartProducts = [];
  final List<AppProduct> _wishlistProducts = [];

  List<AppProduct> get cartProducts => List.unmodifiable(_cartProducts);
  List<AppProduct> get wishlistProducts => List.unmodifiable(_wishlistProducts);

  int get cartCount => _cartProducts.length;

  int get subtotal => _cartProducts.fold(
        0,
        (sum, p) => sum + (int.tryParse(p.price.replaceAll(',', '')) ?? 0),
      );

  void addToCart(AppProduct product, {int quantity = 1}) {
    for (int i = 0; i < quantity; i++) {
      _cartProducts.add(product);
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cartProducts.removeWhere((p) => p.id == productId);
    notifyListeners();
  }

  void removeSingleFromCart(String productId) {
    final idx = _cartProducts.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      _cartProducts.removeAt(idx);
      notifyListeners();
    }
  }

  void clearCart() {
    _cartProducts.clear();
    notifyListeners();
  }

  void resetCustomerCartState() {
    _cartProducts.clear();
    _wishlistProducts.clear();
    notifyListeners();
  }

  bool isProductWishlisted(String productId) {
    return _wishlistProducts.any((p) => p.id == productId);
  }

  Future<void> toggleWishlist(AppProduct product) async {
    final idx = _wishlistProducts.indexWhere((p) => p.id == product.id);
    final isRemoving = idx != -1;
    if (isRemoving) {
      _wishlistProducts.removeAt(idx);
    } else {
      _wishlistProducts.add(product);
    }
    notifyListeners();

    // Persist to Supabase if user is authenticated
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        if (isRemoving) {
          await Supabase.instance.client
              .from('user_wishlists')
              .delete()
              .match({'user_id': user.id, 'product_id': product.id});
        } else {
          await Supabase.instance.client
              .from('user_wishlists')
              .upsert({'user_id': user.id, 'product_id': product.id});
        }
      }
    } catch (_) {
      // Keep optimistic in-memory update for offline / guest / non-initialized mode
    }
  }

  Future<void> syncWishlistFromSupabase(List<AppProduct> availableProducts) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('user_wishlists')
          .select('product_id')
          .eq('user_id', user.id);

      if (res.isNotEmpty) {
        final ids = res.map((r) => r['product_id']?.toString()).toSet();
        _wishlistProducts.clear();
        for (final p in availableProducts) {
          if (ids.contains(p.id)) {
            _wishlistProducts.add(p);
          }
        }
        notifyListeners();
      }
    } catch (_) {
      // Ignored in offline / test environments
    }
  }

  void removeFromWishlist(String productId) {
    _wishlistProducts.removeWhere((p) => p.id == productId);
    notifyListeners();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        Supabase.instance.client
            .from('user_wishlists')
            .delete()
            .match({'user_id': user.id, 'product_id': productId});
      }
    } catch (_) {}
  }

  void clearWishlist() {
    _wishlistProducts.clear();
    notifyListeners();
  }
}
