// ============================================================================
// APNA STORE — SUPABASE ORDERS & FULFILLMENT SERVICE
// File: lib/core/services/supabase_orders_service.dart
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOrdersService {
  final SupabaseClient? _injected;
  SupabaseClient? get _client {
    if (_injected != null) return _injected;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseOrdersService({SupabaseClient? client}) : _injected = client;

  /// Fetch buyer order history with line items and fulfillments
  Future<List<Map<String, dynamic>>> getBuyerOrders() async {
    final client = _client;
    if (client == null) return [];
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('buyer_orders')
          .select('*, order_items(*), store_fulfillments(*)')
          .eq('customer_user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching buyer orders: $e');
      return [];
    }
  }

  /// Fetch seller store fulfillments for current seller store
  Future<List<Map<String, dynamic>>> getSellerStoreFulfillments(String storeId) async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client
          .from('store_fulfillments')
          .select('*, buyer_orders(*, order_items(*))')
          .eq('seller_store_id', storeId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching seller fulfillments: $e');
      return [];
    }
  }

  /// Seller updates store fulfillment status via RPC
  Future<Map<String, dynamic>> updateFulfillmentStatus({
    required String orderId,
    required String newStatus,
    String? courierName,
    String? trackingNumber,
    String? notes,
  }) async {
    final client = _client;
    if (client == null) {
      return {'success': true, 'order_id': orderId, 'status': newStatus};
    }
    try {
      final response = await client.rpc('seller_update_fulfillment_status', params: {
        'p_order_id': orderId,
        'p_new_status': newStatus,
        'p_courier_name': courierName,
        'p_tracking_number': trackingNumber,
        'p_notes': notes,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error updating store fulfillment status: $e');
      rethrow;
    }
  }

  /// Cancel order via server-authoritative RPC
  Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    String? sellerStoreId,
    String reason = 'Cancelled by user',
  }) async {
    final client = _client;
    if (client == null) {
      return {'success': true, 'order_id': orderId, 'status': 'Cancelled'};
    }
    try {
      final response = await client.rpc('cancel_order', params: {
        'p_order_id': orderId,
        'p_seller_store_id': sellerStoreId,
        'p_reason': reason,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      rethrow;
    }
  }

  /// Fetch all buyer orders for presentation/cache reconciliation
  Future<List<Map<String, dynamic>>> fetchAllOrders() async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client.from('buyer_orders').select('*');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all orders: $e');
      rethrow;
    }
  }

  /// Fetch tracking timeline events for an order
  Future<List<Map<String, dynamic>>> getOrderTrackingEvents(String orderId) async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client
          .from('order_tracking_events')
          .select('*')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching order tracking events: $e');
      return [];
    }
  }
}
