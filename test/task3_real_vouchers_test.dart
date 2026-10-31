import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/services/supabase_voucher_service.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

void main() {
  group('Task 3: Real Vouchers & Redemptions', () {
    test('VoucherValidationResult factory handles successful rpc responses', () {
      final rpcMap = {
        'valid': true,
        'discount_amount': 250.0,
        'voucher_id': 'f7d2f9d5-7188-4c8d-8a21-4f1a2e3d4c5b',
        'code': 'SUMMERSALE',
        'error': null,
      };

      final result = VoucherValidationResult.fromRpc(rpcMap);
      expect(result.isValid, isTrue);
      expect(result.discountAmount, equals(250.0));
      expect(result.code, equals('SUMMERSALE'));
      expect(result.voucherId, equals('f7d2f9d5-7188-4c8d-8a21-4f1a2e3d4c5b'));
      expect(result.errorMessage, isNull);
    });

    test('VoucherValidationResult factory handles failed rpc responses', () {
      final rpcMap = {
        'valid': false,
        'discount_amount': 0.0,
        'voucher_id': null,
        'code': 'EXPIRED20',
        'error': 'Voucher EXPIRED20 has expired.',
      };

      final result = VoucherValidationResult.fromRpc(rpcMap);
      expect(result.isValid, isFalse);
      expect(result.discountAmount, equals(0.0));
      expect(result.errorMessage, contains('expired'));
    });

    test('SupabaseVoucherService rejects empty or whitespace code without network call', () async {
      final service = SupabaseVoucherService();
      final res = await service.validateVoucher(code: '   ', subtotal: 1500.0);
      expect(res.isValid, isFalse);
      expect(res.errorMessage, equals('Please enter a voucher code'));
    });

    test('SupabaseVoucherService rejects non-positive subtotal without network call', () async {
      final service = SupabaseVoucherService();
      final res = await service.validateVoucher(code: 'PROMO10', subtotal: 0.0);
      expect(res.isValid, isFalse);
      expect(res.errorMessage, equals('Cart subtotal must be greater than zero'));
    });

    test('AppStateProvider initializes with empty vouchers (no hardcoded discounts)', () {
      final state = AppStateProvider();
      expect(state.vouchers.isEmpty, isTrue, reason: 'Must not contain hardcoded vouchers like EID2026 or WELCOME500');
    });
  });
}
