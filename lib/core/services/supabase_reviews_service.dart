// ============================================================================
// APNA STORE — SUPABASE PRODUCT REVIEWS SERVICE
// File: lib/core/services/supabase_reviews_service.dart
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseReviewsService {
  final SupabaseClient? _injected;
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  SupabaseReviewsService({SupabaseClient? client}) : _injected = client;

  /// Submit product review for a verified delivered order item
  Future<Map<String, dynamic>> submitProductReview({
    required String productId,
    required String orderItemId,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await _client.rpc('submit_product_review', params: {
        'p_product_id': productId,
        'p_order_item_id': orderItemId,
        'p_rating': rating,
        'p_comment': comment,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error submitting product review: $e');
      rethrow;
    }
  }

  /// Fetch public product reviews for a given product
  Future<List<Map<String, dynamic>>> getProductReviews(String productId) async {
    try {
      final response = await _client
          .from('product_reviews')
          .select('*, profiles(full_name)')
          .eq('product_id', productId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching product reviews: $e');
      return [];
    }
  }

  /// Fetch all reviews for Super Admin moderation screen
  Future<List<Map<String, dynamic>>> fetchAllReviewsForModeration() async {
    try {
      final response = await _client.from('product_reviews').select('*');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all reviews for moderation: $e');
      return [];
    }
  }
}
