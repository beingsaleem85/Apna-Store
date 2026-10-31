import 'dart:convert';
import '../../utils/parsing_helpers.dart';

/// Canonical Order Database Transfer Object for `buyer_orders` table.
class OrderDto {
  final String id;
  final String customerName;
  final String customerEmail;
  final double amount;
  final String paymentMethod;
  final List<Map<String, dynamic>> items;
  final String status;
  final DateTime? createdAt;

  OrderDto({
    required this.id,
    required this.customerName,
    required this.customerEmail,
    required this.amount,
    required this.paymentMethod,
    required this.items,
    this.status = 'Pending',
    this.createdAt,
  });

  /// Maps database row (snake_case) to OrderDto safely.
  factory OrderDto.fromDatabaseMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> parsedItems = [];
    final rawItems = map['items'];
    if (rawItems is List) {
      parsedItems = rawItems.map((i) => i is Map<String, dynamic> ? i : Map<String, dynamic>.from(i as Map)).toList();
    } else if (rawItems is String && rawItems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems);
        if (decoded is List) {
          parsedItems = decoded.map((i) => i is Map<String, dynamic> ? i : Map<String, dynamic>.from(i as Map)).toList();
        }
      } catch (_) {}
    }

    return OrderDto(
      id: (map['id'] ?? '').toString(),
      customerName: (map['customer_name'] ?? '').toString(),
      customerEmail: (map['customer_email'] ?? '').toString(),
      amount: ParsingHelpers.parseDouble(map['amount']),
      paymentMethod: (map['payment_method'] ?? 'COD').toString(),
      items: parsedItems,
      status: (map['status'] ?? 'Pending').toString(),
      createdAt: ParsingHelpers.parseDateTime(map['created_at']),
    );
  }

  /// Maps OrderDto to canonical database column payload (snake_case).
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'amount': amount,
      'payment_method': paymentMethod,
      'items': items,
      'status': status,
      'created_at': ParsingHelpers.toIsoString(createdAt ?? DateTime.now()),
    };
  }
}
