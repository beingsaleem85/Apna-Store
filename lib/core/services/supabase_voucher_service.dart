import 'package:supabase_flutter/supabase_flutter.dart';

class VoucherValidationResult {
  final bool isValid;
  final double discountAmount;
  final String? voucherId;
  final String? code;
  final String? errorMessage;

  const VoucherValidationResult({
    required this.isValid,
    this.discountAmount = 0.0,
    this.voucherId,
    this.code,
    this.errorMessage,
  });

  factory VoucherValidationResult.fromRpc(Map<String, dynamic> data) {
    final valid = data['valid'] == true;
    final discount = (data['discount_amount'] as num?)?.toDouble() ?? 0.0;
    return VoucherValidationResult(
      isValid: valid,
      discountAmount: discount,
      voucherId: data['voucher_id']?.toString(),
      code: data['code']?.toString(),
      errorMessage: data['error']?.toString(),
    );
  }

  factory VoucherValidationResult.failed(String message) {
    return VoucherValidationResult(
      isValid: false,
      discountAmount: 0.0,
      errorMessage: message,
    );
  }
}

class SupabaseVoucherService {
  final SupabaseClient? _injectedClient;
  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;

  SupabaseVoucherService({SupabaseClient? client}) : _injectedClient = client;

  /// Calls server RPC `validate_voucher` to check validity, min order, expiry, and calculate discount
  Future<VoucherValidationResult> validateVoucher({
    required String code,
    required double subtotal,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return VoucherValidationResult.failed('Please enter a voucher code');
    }
    if (subtotal <= 0) {
      return VoucherValidationResult.failed('Cart subtotal must be greater than zero');
    }

    try {
      final res = await _supabase.rpc('validate_voucher', params: {
        'p_code': cleanCode,
        'p_subtotal': subtotal,
      });

      if (res is Map<String, dynamic>) {
        return VoucherValidationResult.fromRpc(res);
      } else if (res is Map) {
        return VoucherValidationResult.fromRpc(Map<String, dynamic>.from(res));
      }

      return VoucherValidationResult.failed('Invalid response from server');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('not found') || msg.contains('invalid voucher')) {
        return VoucherValidationResult.failed('Invalid voucher code');
      }
      if (msg.contains('expired')) {
        return VoucherValidationResult.failed('This voucher has expired');
      }
      if (msg.contains('minimum')) {
        return VoucherValidationResult.failed('Minimum order spend not reached for this voucher');
      }
      if (msg.contains('limit') || msg.contains('depleted')) {
        return VoucherValidationResult.failed('This voucher usage limit has been reached');
      }
      return VoucherValidationResult.failed('Could not validate voucher: ${e.toString()}');
    }
  }
}
