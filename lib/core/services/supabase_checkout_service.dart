import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../errors/failures.dart';

/// Server-authoritative checkout service calling `create_atomic_order` RPC
class SupabaseCheckoutService extends ChangeNotifier {
  final SupabaseClient? _injected;
  SupabaseClient get _supabase => _injected ?? Supabase.instance.client;

  bool _isSubmitting = false;
  String? _errorMessage;

  SupabaseCheckoutService({SupabaseClient? client}) : _injected = client;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  String _mapCheckoutError(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('unauthenticated request') || msg.contains('jwt')) {
      return 'Please sign in to place your order.';
    }
    if (msg.contains('online payments are not available yet') || msg.contains('online payments')) {
      return 'Online payments are not available yet. Please select Cash on Delivery.';
    }
    if (msg.contains('insufficient stock for product')) {
      return 'An item in your cart is no longer available in that quantity.';
    }
    if (msg.contains('is unavailable or belongs to an unapproved')) {
      return 'One of the selected products is no longer available.';
    }
    if (msg.contains('payment method') || msg.contains('unsupported payment')) {
      return 'Selected payment method is not supported.';
    }
    if (msg.contains('idempotency conflict')) {
      return 'This order was already submitted. Check your order history.';
    }
    if (msg.contains('cart items array cannot be empty') || msg.contains('empty')) {
      return 'Your cart is empty.';
    }
    return 'We couldn\'t place your order. Please try again.';
  }

  /// Executes atomic checkout on Supabase backend
  Future<Map<String, dynamic>> checkout({
    required String idempotencyKey,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> shippingAddress,
    String paymentMethod = 'COD',
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabase.rpc(
        'create_atomic_order',
        params: {
          'p_idempotency_key': idempotencyKey,
          'p_items': items,
          'p_shipping_address': shippingAddress,
          'p_payment_method': paymentMethod,
        },
      );

      _isSubmitting = false;
      notifyListeners();

      if (response is Map<String, dynamic>) {
        return response;
      }
      return Map<String, dynamic>.from(response as Map);
    } catch (e, st) {
      _isSubmitting = false;
      _errorMessage = _mapCheckoutError(e);
      notifyListeners();
      throw FailureMapper.mapException(e, st);
    }
  }

  /// Quotes truthful order totals directly from Supabase server
  Future<Map<String, dynamic>> quoteOrder({
    required List<Map<String, dynamic>> items,
    String? couponCode,
    String? city,
  }) async {
    try {
      final response = await _supabase.rpc(
        'quote_order',
        params: {
          'p_items': items,
          'p_coupon_code': couponCode,
          'p_city': city,
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      return Map<String, dynamic>.from(response as Map);
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }
}
