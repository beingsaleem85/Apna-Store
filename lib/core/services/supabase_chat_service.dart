// ============================================================================
// APNA STORE — SUPABASE AUTHENTICATED CHAT SERVICE
// File: lib/core/services/supabase_chat_service.dart
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseChatService {
  final SupabaseClient? _injected;
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  SupabaseChatService({SupabaseClient? client}) : _injected = client;

  /// Fetch chat rooms for current user
  Future<List<Map<String, dynamic>>> getChatRooms() async {
    try {
      final response = await _client
          .from('chat_rooms')
          .select('*, seller_stores(shop_name, logo_url), products(name)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching chat rooms: $e');
      return [];
    }
  }

  /// Fetch messages for a specific room
  Future<List<Map<String, dynamic>>> getRoomMessages(String roomId) async {
    try {
      final response = await _client
          .from('chat_messages')
          .select('*')
          .eq('room_id', roomId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching room messages: $e');
      return [];
    }
  }

  /// Send message via server-authoritative RPC
  Future<Map<String, dynamic>> sendMessage({
    required String roomId,
    required String messageText,
  }) async {
    try {
      final response = await _client.rpc('send_chat_message', params: {
        'p_room_id': roomId,
        'p_message_text': messageText,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error sending chat message: $e');
      rethrow;
    }
  }
}
