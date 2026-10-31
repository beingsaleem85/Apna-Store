// ============================================================================
// APNA STORE — SUPABASE RETURNS & DISPUTES SERVICE
// File: lib/core/services/supabase_returns_service.dart
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseReturnsService {
  final SupabaseClient? _injected;
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  SupabaseReturnsService({SupabaseClient? client}) : _injected = client;

  /// Submit a return request for a delivered order line item
  Future<Map<String, dynamic>> submitReturnRequest({
    required String orderId,
    required String orderItemId,
    required int quantity,
    required String reason,
    String? description,
    List<String> evidencePaths = const [],
  }) async {
    try {
      final response = await _client.rpc('submit_return_request', params: {
        'p_order_id': orderId,
        'p_order_item_id': orderItemId,
        'p_quantity': quantity,
        'p_reason': reason,
        'p_description': description,
        'p_evidence_paths': evidencePaths,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error submitting return request: $e');
      rethrow;
    }
  }

  /// Review return request (Approve or Reject) via server RPC (triggers Phase 10 refund if Approved)
  Future<Map<String, dynamic>> reviewReturnRequest({
    required String returnId,
    required String decision, // 'Approved' or 'Rejected'
    String? adminNotes,
  }) async {
    try {
      final response = await _client.rpc('review_return_request', params: {
        'p_return_id': returnId,
        'p_decision': decision,
        'p_admin_notes': adminNotes,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error reviewing return request: $e');
      rethrow;
    }
  }

  /// Fetch return requests for current buyer or seller
  Future<List<Map<String, dynamic>>> getReturnRequests({String? sellerStoreId}) async {
    try {
      var query = _client.from('return_requests').select('*, buyer_orders(*)');
      if (sellerStoreId != null) {
        query = query.eq('seller_store_id', sellerStoreId);
      }
      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching return requests: $e');
      return [];
    }
  }
}
