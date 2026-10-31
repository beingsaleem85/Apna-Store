import 'package:flutter/foundation.dart';
import '../services/app_state_provider.dart';
import '../services/supabase_orders_service.dart';

class OrdersController extends ChangeNotifier {
  final List<AppOrder> _orders = [];
  bool _isLoadingOrders = false;
  String? _ordersError;
  final SupabaseOrdersService _ordersService;

  OrdersController({SupabaseOrdersService? ordersService})
      : _ordersService = ordersService ?? SupabaseOrdersService();

  List<AppOrder> get orders => List.unmodifiable(_orders);
  bool get isLoadingOrders => _isLoadingOrders;
  String? get ordersError => _ordersError;

  Future<void> fetchOrdersFromSupabase() async {
    _isLoadingOrders = true;
    _ordersError = null;
    notifyListeners();

    try {
      final response = await _ordersService.getBuyerOrders();
      if (response.isNotEmpty) {
        _orders.clear();
        for (var item in response) {
          _orders.add(AppOrder.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    } catch (e) {
      debugPrint('SupabaseOrdersService getBuyerOrders error: $e');
      _ordersError = e.toString();
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  AppOrder? getOrderById(String orderId) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    return idx != -1 ? _orders[idx] : null;
  }

  List<AppOrder> getOrdersForBuyer(String buyerName) {
    return _orders.where((o) => o.buyerName == buyerName).toList();
  }

  List<AppOrder> getOrdersForSeller(String sellerId) {
    return _orders.where((o) => o.sellerId == sellerId).toList();
  }

  /// PRESENTATION CACHE SYNC ONLY
  /// Syncs local presentation cache after canonical backend order creation success.
  void syncAddOrderPresentationCache(AppOrder order) {
    _orders.add(order);
    notifyListeners();
  }

  /// PRESENTATION CACHE SYNC ONLY
  /// Syncs local presentation cache after canonical backend fulfillment update success.
  void syncUpdateOrderStatusCache(String orderId, String newStatus) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      _orders[idx].orderStatus = newStatus;
      notifyListeners();
    }
  }

  /// PRESENTATION CACHE SYNC ONLY
  /// Syncs local presentation cache after return request success.
  void syncUpdateReturnStatusCache(String orderId, String reason, String disputeStatus) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      _orders[idx].orderStatus = 'Returned';
      _orders[idx].returnReason = reason;
      _orders[idx].disputeStatus = disputeStatus;
      notifyListeners();
    }
  }

  /// PRESENTATION CACHE SYNC ONLY
  /// Clears local presentation order cache.
  void clearOrdersCache() {
    _orders.clear();
    notifyListeners();
  }

  /// PRESENTATION CACHE SYNC ONLY
  /// Clears seller specific orders from presentation cache.
  void clearOrdersForSeller(String sellerId) {
    _orders.removeWhere((o) => o.sellerId == sellerId);
    notifyListeners();
  }
}
