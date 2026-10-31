import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/app_state_provider.dart';

class RealReturnRequestItem {
  final String id;
  final String orderId;
  final String customerName;
  final String reason;
  final String? description;
  final int quantity;
  String status;
  final DateTime createdAt;

  RealReturnRequestItem({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.reason,
    this.description,
    required this.quantity,
    required this.status,
    required this.createdAt,
  });
}

class SellerReturnsDisputesScreen extends StatefulWidget {
  const SellerReturnsDisputesScreen({super.key});

  @override
  State<SellerReturnsDisputesScreen> createState() => _SellerReturnsDisputesScreenState();
}

class _SellerReturnsDisputesScreenState extends State<SellerReturnsDisputesScreen> {
  String _activeTab = 'Requested';
  final List<RealReturnRequestItem> _returns = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReturns();
  }

  Future<void> _fetchReturns() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      String? storeId = appState.loggedInSellerId;

      if (storeId == null || storeId.isEmpty) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final res = await Supabase.instance.client
              .from('seller_stores')
              .select('id')
              .eq('owner_id', user.id)
              .maybeSingle();
          if (res != null) {
            storeId = res['id']?.toString();
          }
        }
      }

      if (storeId == null || storeId.isEmpty) {
        setState(() {
          _returns.clear();
          _isLoading = false;
        });
        return;
      }

      final data = await Supabase.instance.client
          .from('return_requests')
          .select('id, order_id, quantity, reason, description, status, created_at, profiles:customer_user_id(full_name)')
          .eq('seller_store_id', storeId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _returns.clear();
          for (final row in (data as List)) {
            final profile = row['profiles'] is Map ? row['profiles'] : null;
            final customer = profile != null && profile['full_name'] != null
                ? profile['full_name'].toString()
                : 'Customer';

            _returns.add(RealReturnRequestItem(
              id: row['id'].toString(),
              orderId: (row['order_id'] ?? '').toString(),
              customerName: customer,
              reason: (row['reason'] ?? 'Return requested').toString(),
              description: row['description']?.toString(),
              quantity: (row['quantity'] as num?)?.toInt() ?? 1,
              status: (row['status'] ?? 'Requested').toString(),
              createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
            ));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load return requests: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleReview(RealReturnRequestItem item, String newStatus) async {
    try {
      await Supabase.instance.client.rpc(
        'review_return_request',
        params: {
          'p_request_id': item.id,
          'p_new_status': newStatus,
          'p_admin_notes': 'Reviewed by seller from Seller Returns Desk',
        },
      );

      setState(() => item.status = newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Return request marked as $newStatus!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update return: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _returns.where((r) => r.status.toLowerCase() == _activeTab.toLowerCase()).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Returns, Exchanges & Disputes Desk'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReturns,
            tooltip: 'Refresh Returns',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchReturns, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Policy Banner
                      Card(
                        color: const Color(0xFF004D40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(Icons.assignment_return, color: Color(0xFFFDB913), size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Customer Return & Dispute Resolution Desk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    SizedBox(height: 2),
                                    Text('Review return requests within 48 hours to resolve disputes efficiently.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Status Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Requested', 'Approved', 'Rejected', 'Completed'].map((tab) {
                            final isSel = _activeTab == tab;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(tab, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                selected: isSel,
                                selectedColor: const Color(0xFF004D40),
                                onSelected: (val) => setState(() => _activeTab = tab),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Returns List
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey),
                                      const SizedBox(height: 12),
                                      Text('No return requests in "$_activeTab" status.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      const Text('Customer return and exchange requests will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                separatorBuilder: (ctx, i) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];

                                  return ListTile(
                                    title: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Return ${item.id.substring(0, 8).toUpperCase()} — ${item.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('Qty: ${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Order ID: ${item.orderId}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                        Text('Reason: ${item.reason}', style: const TextStyle(fontSize: 11)),
                                        if (item.description != null && item.description!.isNotEmpty)
                                          Text('Details: ${item.description}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        const SizedBox(height: 8),
                                        if (item.status == 'Requested')
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                                                onPressed: () => _handleReview(item, 'Approved'),
                                                child: const Text('Approve Return', style: TextStyle(fontSize: 11)),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                                onPressed: () => _handleReview(item, 'Rejected'),
                                                child: const Text('Reject', style: TextStyle(fontSize: 11)),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
