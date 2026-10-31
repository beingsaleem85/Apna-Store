import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/services/supabase_orders_service.dart';

class MockBuyerScopedOrdersService extends SupabaseOrdersService {
  final String activeBuyerId;
  bool getBuyerOrdersCalled = false;

  MockBuyerScopedOrdersService({required this.activeBuyerId});

  @override
  Future<List<Map<String, dynamic>>> getBuyerOrders() async {
    getBuyerOrdersCalled = true;

    // Database RLS & Service Filter (.eq('customer_user_id', userId)) simulation
    final allOrders = [
      {
        'id': 'ord_a_100',
        'customer_user_id': 'buyer_a_uuid',
        'product_id': 'p_101',
        'buyer_name': 'Buyer A User',
        'seller_id': 'seller_store_01',
        'status': 'Delivered',
        'price': 2499.0,
      },
      {
        'id': 'ord_b_200',
        'customer_user_id': 'buyer_b_uuid',
        'product_id': 'p_202',
        'buyer_name': 'Buyer B User',
        'seller_id': 'seller_store_02',
        'status': 'Confirmed',
        'price': 3499.0,
      },
    ];

    return allOrders.where((o) => o['customer_user_id'] == activeBuyerId).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 12 Step F1.2 Characterization Tests — Buyer Order Scope & Final Routing Closure', () {
    test('A. Buyer A cannot receive Buyer B order', () async {
      final serviceBuyerA = MockBuyerScopedOrdersService(activeBuyerId: 'buyer_a_uuid');
      final controllerBuyerA = OrdersController(ordersService: serviceBuyerA);

      await controllerBuyerA.fetchOrdersFromSupabase();

      expect(controllerBuyerA.orders.length, 1);
      expect(controllerBuyerA.orders.first.id, 'ord_a_100');
      expect(controllerBuyerA.orders.any((o) => o.id == 'ord_b_200'), isFalse);
    });

    test('B. Buyer B cannot receive Buyer A order', () async {
      final serviceBuyerB = MockBuyerScopedOrdersService(activeBuyerId: 'buyer_b_uuid');
      final controllerBuyerB = OrdersController(ordersService: serviceBuyerB);

      await controllerBuyerB.fetchOrdersFromSupabase();

      expect(controllerBuyerB.orders.length, 1);
      expect(controllerBuyerB.orders.first.id, 'ord_b_200');
      expect(controllerBuyerB.orders.any((o) => o.id == 'ord_a_100'), isFalse);
    });

    test('C. OrdersController uses buyer-safe service path getBuyerOrders()', () async {
      final service = MockBuyerScopedOrdersService(activeBuyerId: 'buyer_a_uuid');
      final controller = OrdersController(ordersService: service);

      await controller.fetchOrdersFromSupabase();

      expect(service.getBuyerOrdersCalled, isTrue);
    });

    test('D. Backend database RLS remains order privacy authority', () {
      final rlsMigration = File('supabase/migrations/20260805000000_authoritative_schema_and_rls.sql').readAsStringSync();
      expect(rlsMigration.contains('customer_user_id = auth.uid()') || rlsMigration.contains('auth.uid() = customer_user_id'), isTrue);
    });

    test('E. No direct buyer_orders mutation exists in presentation or controllers', () {
      final controllerContent = File('lib/core/controllers/orders_controller.dart').readAsStringSync();
      expect(controllerContent.contains(".from('buyer_orders').update"), isFalse);
      expect(controllerContent.contains(".from('buyer_orders').insert"), isFalse);
      expect(controllerContent.contains(".from('buyer_orders').delete"), isFalse);
    });
  });
}
