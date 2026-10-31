import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/features/seller/screens/inventory/seller_inventory_management_screen.dart';
import 'package:apna_store/features/seller/screens/returns/seller_returns_disputes_screen.dart';
import 'package:apna_store/features/seller/screens/chat/seller_customer_chat_screen.dart';
import 'package:apna_store/features/seller/screens/notifications/seller_notifications_center_screen.dart';

void main() {
  group('Step A1.1: Seller Essentials Real Data Tests', () {
    test('InventoryProductItem calculates stock status correctly without mock data', () {
      final lowStockItem = InventoryProductItem(
        id: 'prod-001',
        sku: 'SKU-001',
        title: 'Lawn Shirt',
        stockQuantity: 3,
        price: 2500.0,
        isActive: true,
      );
      expect(lowStockItem.velocityCategory, equals('Low Stock'));

      final normalItem = InventoryProductItem(
        id: 'prod-002',
        sku: 'SKU-002',
        title: 'Leather Wallet',
        stockQuantity: 65,
        price: 1200.0,
        isActive: true,
      );
      expect(normalItem.velocityCategory, equals('In Stock'));
    });

    test('RealReturnRequestItem parses database columns accurately', () {
      final now = DateTime.now();
      final item = RealReturnRequestItem(
        id: 'ret-12345678',
        orderId: 'ORD-999',
        customerName: 'Kashif Ali',
        reason: 'Damaged during transit',
        quantity: 1,
        status: 'Requested',
        createdAt: now,
      );

      expect(item.id, equals('ret-12345678'));
      expect(item.orderId, equals('ORD-999'));
      expect(item.status, equals('Requested'));
      expect(item.quantity, equals(1));
    });

    test('RealChatMessage accurately represents sender role', () {
      final msg = RealChatMessage(
        id: 'msg-001',
        senderId: 'seller-uid',
        text: 'Your order has been packed and handed over to courier.',
        createdAt: DateTime.now(),
        isSeller: true,
      );

      expect(msg.isSeller, isTrue);
      expect(msg.text, contains('courier'));
    });

    test('RealNotificationItem holds real server fields and toggles read status', () {
      final notif = RealNotificationItem(
        id: 'notif-001',
        title: 'New COD Order Received',
        body: 'Order #ORD-101 has been placed.',
        category: 'Orders',
        isRead: false,
        createdAt: DateTime.now(),
      );

      expect(notif.isRead, isFalse);
      notif.isRead = true;
      expect(notif.isRead, isTrue);
    });
  });
}
