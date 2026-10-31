import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerWalletSummary {
  final String sellerStoreId;
  final double availableBalance;
  final double pendingBalance;
  final double heldBalance;
  final double paidOutTotal;

  SellerWalletSummary({
    required this.sellerStoreId,
    required this.availableBalance,
    required this.pendingBalance,
    required this.heldBalance,
    required this.paidOutTotal,
  });

  factory SellerWalletSummary.fromJson(Map<String, dynamic> json) {
    return SellerWalletSummary(
      sellerStoreId: json['seller_store_id']?.toString() ?? '',
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0.0,
      pendingBalance: (json['pending_balance'] as num?)?.toDouble() ?? 0.0,
      heldBalance: (json['held_balance'] as num?)?.toDouble() ?? 0.0,
      paidOutTotal: (json['paid_out_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WalletTxnRecord {
  final String id;
  final String transactionType;
  final double amount;
  final String sourceType;
  final String sourceId;
  final String description;
  final DateTime createdAt;

  WalletTxnRecord({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.sourceType,
    required this.sourceId,
    required this.description,
    required this.createdAt,
  });

  factory WalletTxnRecord.fromJson(Map<String, dynamic> json) {
    return WalletTxnRecord(
      id: json['id']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? 'CREDIT',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      sourceType: json['source_type']?.toString() ?? '',
      sourceId: json['source_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class PayoutRequestRecord {
  final String id;
  final String sellerStoreId;
  final double amount;
  final String status;
  final String? bankName;
  final String? iban;
  final String? adminNotes;
  final DateTime createdAt;

  PayoutRequestRecord({
    required this.id,
    required this.sellerStoreId,
    required this.amount,
    required this.status,
    this.bankName,
    this.iban,
    this.adminNotes,
    required this.createdAt,
  });

  factory PayoutRequestRecord.fromJson(Map<String, dynamic> json) {
    return PayoutRequestRecord(
      id: json['id']?.toString() ?? '',
      sellerStoreId: json['seller_store_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Requested',
      bankName: json['bank_name']?.toString(),
      iban: json['iban']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class SupabaseFinanceService {
  final SupabaseClient? _injected;
  SupabaseClient? get _safeClient {
    if (_injected != null) return _injected;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _client => _safeClient ?? Supabase.instance.client;

  SupabaseFinanceService({SupabaseClient? client}) : _injected = client;

  /// Fetch derived wallet summary balances for seller store
  Future<SellerWalletSummary?> fetchSellerWalletSummary({String? sellerStoreId}) async {
    try {
      final client = _safeClient;
      if (client == null) return null;
      final response = await client.rpc(
        'get_seller_wallet_summary',
        params: sellerStoreId != null ? {'p_seller_store_id': sellerStoreId} : {},
      );

      if (response is List && response.isNotEmpty) {
        return SellerWalletSummary.fromJson(Map<String, dynamic>.from(response.first as Map));
      }
      return null;
    } catch (e) {
      debugPrint('Supabase fetchSellerWalletSummary error: $e');
      return null;
    }
  }

  /// Fetch append-only wallet transaction history
  Future<List<WalletTxnRecord>> fetchWalletTransactions({String? sellerStoreId}) async {
    try {
      final client = _safeClient;
      if (client == null) return [];
      var query = client.from('wallet_transactions').select();
      if (sellerStoreId != null) {
        query = query.eq('seller_store_id', sellerStoreId);
      }
      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((item) => WalletTxnRecord.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('Supabase fetchWalletTransactions error: $e');
      return [];
    }
  }

  /// Submit server-authoritative payout request with atomic hold reservation
  Future<Map<String, dynamic>> requestPayout({
    required double amount,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client.rpc(
        'seller_request_payout',
        params: {
          'p_amount': amount,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Supabase requestPayout error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Fetch payout requests list
  Future<List<PayoutRequestRecord>> fetchPayoutRequests() async {
    try {
      final response = await _client
          .from('payout_requests')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => PayoutRequestRecord.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('Supabase fetchPayoutRequests error: $e');
      return [];
    }
  }

  /// Admin process payout request (Approve, Pay/Process, Reject)
  Future<Map<String, dynamic>> processPayout({
    required String payoutId,
    required String action,
    String? notes,
  }) async {
    try {
      final response = await _client.rpc(
        'admin_process_payout',
        params: {
          'p_payout_id': payoutId,
          'p_action': action,
          'p_notes': notes,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Supabase processPayout error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Admin COD order settlement RPC
  Future<Map<String, dynamic>> processCodSettlement({
    required String orderId,
    String action = 'Settle',
  }) async {
    try {
      final response = await _client.rpc(
        'admin_process_cod_settlement',
        params: {
          'p_order_id': orderId,
          'p_action': action,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Supabase processCodSettlement error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Admin process order item refund RPC
  Future<Map<String, dynamic>> processRefund({
    required String orderId,
    required String orderItemId,
    required double amount,
    required String reason,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client.rpc(
        'admin_process_refund',
        params: {
          'p_order_id': orderId,
          'p_order_item_id': orderItemId,
          'p_amount': amount,
          'p_reason': reason,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Supabase processRefund error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Admin adjust seller wallet RPC
  Future<Map<String, dynamic>> adjustSellerWallet({
    required String sellerStoreId,
    required double amount,
    required String reason,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _client.rpc(
        'admin_adjust_seller_wallet',
        params: {
          'p_store_id': sellerStoreId,
          'p_amount': amount,
          'p_reason': reason,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Supabase adjustSellerWallet error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
