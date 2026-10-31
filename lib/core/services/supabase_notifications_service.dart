// ============================================================================
// APNA STORE — SUPABASE PERSISTED NOTIFICATIONS SERVICE
// File: lib/core/services/supabase_notifications_service.dart
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNotificationsService {
  final SupabaseClient? _injected;
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  SupabaseNotificationsService({SupabaseClient? client}) : _injected = client;

  /// Fetch notifications for authenticated user
  Future<List<Map<String, dynamic>>> getUserNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark notification as read via server RPC
  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _client.rpc('mark_notification_read', params: {
        'p_notification_id': notificationId,
      });
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }
}
