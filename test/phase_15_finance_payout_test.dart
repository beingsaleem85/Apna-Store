import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/services/supabase_finance_service.dart';
import 'package:apna_store/features/seller/screens/finance/seller_wallet_payout_screen.dart';

void main() {
  group('Phase C — M16 & M17 Finance, Payouts & Category Governance Tests', () {
    test('SellerWalletSummary deserializes accurately', () {
      final json = {
        'seller_store_id': 'store-123',
        'available_balance': 45000.50,
        'pending_balance': 12000.00,
        'held_balance': 5000.00,
        'paid_out_total': 180000.00,
      };

      final summary = SellerWalletSummary.fromJson(json);
      expect(summary.sellerStoreId, 'store-123');
      expect(summary.availableBalance, 45000.50);
      expect(summary.pendingBalance, 12000.00);
      expect(summary.heldBalance, 5000.00);
      expect(summary.paidOutTotal, 180000.00);
    });

    test('WalletTxnRecord and PayoutRequestRecord parse JSON correctly', () {
      final txnJson = {
        'id': 'txn-001',
        'transaction_type': 'CREDIT',
        'amount': 2500.00,
        'source_type': 'ORDER_DELIVERY',
        'source_id': 'ord-999',
        'description': 'Settlement for delivered order #ord-999',
        'created_at': '2026-08-20T10:00:00Z',
      };

      final txn = WalletTxnRecord.fromJson(txnJson);
      expect(txn.id, 'txn-001');
      expect(txn.transactionType, 'CREDIT');
      expect(txn.amount, 2500.00);
      expect(txn.sourceType, 'ORDER_DELIVERY');

      final payoutJson = {
        'id': 'payout-001',
        'seller_store_id': 'store-123',
        'amount': 15000.00,
        'status': 'Pending',
        'bank_name': 'Meezan Bank Ltd',
        'iban': 'PK36MEZN0001020304050607',
        'admin_notes': null,
        'created_at': '2026-08-20T10:30:00Z',
      };

      final payout = PayoutRequestRecord.fromJson(payoutJson);
      expect(payout.id, 'payout-001');
      expect(payout.amount, 15000.00);
      expect(payout.status, 'Pending');
      expect(payout.bankName, 'Meezan Bank Ltd');
    });

    testWidgets('SellerWalletPayoutScreen renders wallet interface gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SellerWalletPayoutScreen(),
        ),
      );

      // Verify that the initial loading or screen renders without exceptions
      await tester.pumpAndSettle();
      expect(find.text('Merchant Wallet & Tax Invoicing'), findsOneWidget);
    });
  });
}
