import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';
import '../../../../core/services/supabase_chat_service.dart';

// 1. Executive Customer List Section (Customer Directory)
class SellerCustomerListSection extends StatefulWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerCustomerListSection({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  @override
  State<SellerCustomerListSection> createState() => _SellerCustomerListSectionState();
}

class _SellerCustomerListSectionState extends State<SellerCustomerListSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedTierFilter = 'All';

  final List<Map<String, String>> _customers = [
    {
      'name': 'Ali Khan',
      'email': 'ali.khan@gmail.com',
      'phone': '0300-8842109',
      'city': 'Lahore',
      'ordersCount': '8 Orders',
      'totalSpent': 'PKR 42,500',
      'tier': 'VIP Gold',
      'lastOrder': '18 Aug 2026',
    },
    {
      'name': 'Fatima Shah',
      'email': 'fatima.shah@yahoo.com',
      'phone': '0321-4458921',
      'city': 'Karachi',
      'ordersCount': '5 Orders',
      'totalSpent': 'PKR 28,000',
      'tier': 'VIP Gold',
      'lastOrder': '15 Aug 2026',
    },
    {
      'name': 'Muhammad Usman',
      'email': 'usman.m@outlook.com',
      'phone': '0333-1122334',
      'city': 'Islamabad',
      'ordersCount': '3 Orders',
      'totalSpent': 'PKR 14,200',
      'tier': 'Regular Buyer',
      'lastOrder': '12 Aug 2026',
    },
    {
      'name': 'Saima Malik',
      'email': 'saima.malik@gmail.com',
      'phone': '0312-9988776',
      'city': 'Multan',
      'ordersCount': '2 Orders',
      'totalSpent': 'PKR 8,900',
      'tier': 'Regular Buyer',
      'lastOrder': '05 Aug 2026',
    },
    {
      'name': 'Zubair Ahmed',
      'email': 'zubair.a@gmail.com',
      'phone': '0345-6677889',
      'city': 'Rawalpindi',
      'ordersCount': '1 Order',
      'totalSpent': 'PKR 3,500',
      'tier': 'New Buyer',
      'lastOrder': '01 Aug 2026',
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildKpiBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierBadge(String tier) {
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF475569);

    if (tier == 'VIP Gold') {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFB45309);
    } else if (tier == 'Regular Buyer') {
      bg = const Color(0xFFE0F2FE);
      text = const Color(0xFF0284C7);
    } else if (tier == 'New Buyer') {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF059669);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(tier, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchCtrl.text.toLowerCase();
    final filtered = _customers.where((c) {
      final matchesSearch = searchQuery.isEmpty ||
          c['name']!.toLowerCase().contains(searchQuery) ||
          c['email']!.toLowerCase().contains(searchQuery) ||
          c['phone']!.toLowerCase().contains(searchQuery) ||
          c['city']!.toLowerCase().contains(searchQuery);
      final matchesTier = _selectedTierFilter == 'All' || c['tier'] == _selectedTierFilter;
      return matchesSearch && matchesTier;
    }).toList();

    final totalCount = _customers.length;
    final vipCount = _customers.where((c) => c['tier'] == 'VIP Gold').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Customer Directory & CRM Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('View buyer profiles, lifetime order values, purchase history, and buyer tier statuses.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer Directory exported to CSV!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.download_outlined, size: 14),
                label: const Text('Export Customers CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildKpiBox('Total Store Customers', '$totalCount Buyers', Icons.people_outline, const Color(0xFF0284C7)),
                  _buildKpiBox('VIP Gold Members', '$vipCount VIPs', Icons.workspace_premium_outlined, const Color(0xFFB45309)),
                  _buildKpiBox('Repeat Buyers Rate', '42% Repeat Rate', Icons.sync_outlined, const Color(0xFF059669)),
                  _buildKpiBox('Avg Customer Value', 'PKR 19,400', Icons.payments_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Controls & Data Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search customer name, email, phone, or city...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filter Tier Dropdown
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 38,
                        child: DropdownButtonFormField<String>(
                          value: _selectedTierFilter,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Customer Tiers')),
                            DropdownMenuItem(value: 'VIP Gold', child: Text('VIP Gold Members')),
                            DropdownMenuItem(value: 'Regular Buyer', child: Text('Regular Buyers')),
                            DropdownMenuItem(value: 'New Buyer', child: Text('New Buyers')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedTierFilter = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Table Header Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 4, child: Text('CUSTOMER PROFILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('CITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('ORDERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('LIFETIME SPENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('TIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 3, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Customers List
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: const Center(
                      child: Text('No customers match your active search or filter criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final c = filtered[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Customer Profile
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    child: Text(
                                      c['name']![0],
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        const SizedBox(height: 2),
                                        Text('${c['email']} | ${c['phone']}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // City
                            Expanded(flex: 2, child: Text(c['city']!, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),

                            // Orders Count
                            Expanded(flex: 2, child: Text(c['ordersCount']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),

                            // Lifetime Spent
                            Expanded(flex: 2, child: Text(c['totalSpent']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)))),

                            // Tier Badge
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildTierBadge(c['tier']!),
                              ),
                            ),

                            // Actions
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Opening live chat with ${c['name']}...'), backgroundColor: const Color(0xFF2563EB)),
                                      );
                                    },
                                    icon: const Icon(Icons.chat_bubble_outline, size: 14),
                                    label: const Text('Message', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF2563EB),
                                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 2. Executive Customer Messages & Live Chat Center Section
class SellerCustomerMessagesSection extends StatefulWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerCustomerMessagesSection({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  @override
  State<SellerCustomerMessagesSection> createState() => _SellerCustomerMessagesSectionState();
}

class _SellerCustomerMessagesSectionState extends State<SellerCustomerMessagesSection> {
  final TextEditingController _msgCtrl = TextEditingController();
  final TextEditingController _searchChatCtrl = TextEditingController();
  final SupabaseChatService _chatService = SupabaseChatService();

  String _activeCustomer = 'Ali Khan';

  final List<Map<String, String>> _conversations = [
    {
      'name': 'Ali Khan',
      'lastMsg': 'Is the embroidered kurta available in size XL?',
      'time': '2m ago',
      'isOnline': 'true',
      'unread': '1',
    },
    {
      'name': 'Fatima Shah',
      'lastMsg': 'When will my order ORD-984211 be delivered?',
      'time': '15m ago',
      'isOnline': 'true',
      'unread': '0',
    },
    {
      'name': 'Muhammad Usman',
      'lastMsg': 'Thanks for the fast shipping!',
      'time': '1h ago',
      'isOnline': 'false',
      'unread': '0',
    },
    {
      'name': 'Saima Malik',
      'lastMsg': 'Can I request a custom color combination?',
      'time': 'Yesterday',
      'isOnline': 'false',
      'unread': '0',
    },
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    _searchChatCtrl.dispose();
    super.dispose();
  }

  void _sendReply() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    widget.state.sendMessage(_activeCustomer, widget.activeSellerId, text, 'seller');
    try {
      await _chatService.sendMessage(roomId: 'room_$_activeCustomer', messageText: text);
    } catch (_) {}

    _msgCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final chatList = widget.state.getChatroom(_activeCustomer, widget.activeSellerId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer Live Chat & Messaging Inbox', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Real-time buyer chat inquiries, pre-sales product questions, and order status updates.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Main 2-Column Chat Split Desk
          Container(
            height: 600,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Left Column: Customer Conversations List
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Column(
                      children: [
                        // Search Box
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              controller: _searchChatCtrl,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Search chat threads...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),

                        // Conversations List
                        Expanded(
                          child: ListView.separated(
                            itemCount: _conversations.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final conv = _conversations[index];
                              final bool isSelected = conv['name'] == _activeCustomer;
                              final bool isOnline = conv['isOnline'] == 'true';

                              return ListTile(
                                tileColor: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFFDBEAFE),
                                      child: Text(conv['name']![0], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                    ),
                                    if (isOnline)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(conv['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                subtitle: Text(conv['lastMsg']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(conv['time']!, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    if (conv['unread'] != '0') ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                                        child: Text(conv['unread']!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  setState(() => _activeCustomer = conv['name']!);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Column: Active Live Chat Thread
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      // Active Chat Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF2563EB),
                                  child: Text(_activeCustomer[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_activeCustomer, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    const Text('Active Online Inquiry', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                              child: const Text('Linked Order: ORD-984210', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ),
                          ],
                        ),
                      ),

                      // Chat Messages Thread
                      Expanded(
                        child: Container(
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.all(16),
                          child: chatList.isEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.chat_outlined, size: 42, color: Color(0xFFCBD5E1)),
                                    const SizedBox(height: 8),
                                    Text('Start customer conversation with $_activeCustomer', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                  ],
                                )
                              : ListView.builder(
                                  itemCount: chatList.length,
                                  itemBuilder: (context, index) {
                                    final chat = chatList[index];
                                    final isSeller = chat.sender == 'seller';

                                    return Align(
                                      alignment: isSeller ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        constraints: const BoxConstraints(maxWidth: 380),
                                        decoration: BoxDecoration(
                                          color: isSeller ? const Color(0xFF2563EB) : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: isSeller ? null : Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: isSeller ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              chat.message,
                                              style: TextStyle(
                                                color: isSeller ? Colors.white : const Color(0xFF0F172A),
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isSeller ? 'You' : _activeCustomer,
                                              style: TextStyle(
                                                color: isSeller ? Colors.white70 : const Color(0xFF94A3B8),
                                                fontSize: 9,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),

                      // Canned Quick Reply Chips
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: Colors.white,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const Text('Quick Reply:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                              const SizedBox(width: 8),
                              _buildQuickChip('In stock & ready to ship!'),
                              _buildQuickChip('Dispatched via Apna Express'),
                              _buildQuickChip('7-Day free return policy apply'),
                            ],
                          ),
                        ),
                      ),

                      // Input Bar
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _msgCtrl,
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'Type your message to buyer...',
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _sendReply(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                              onPressed: _sendReply,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB))),
        backgroundColor: const Color(0xFFEFF6FF),
        side: BorderSide.none,
        onPressed: () {
          _msgCtrl.text = text;
        },
      ),
    );
  }
}

// 3. Executive Seller Support Tickets & SLA Help Desk
class SellerSupportTicketsSection extends StatefulWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerSupportTicketsSection({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  @override
  State<SellerSupportTicketsSection> createState() => _SellerSupportTicketsSectionState();
}

class _SellerSupportTicketsSectionState extends State<SellerSupportTicketsSection> {
  final List<Map<String, String>> _tickets = [
    {
      'id': 'TCK-9901',
      'subject': 'Bank Payout IBAN Verification Inquiry',
      'category': 'Finance & Payouts',
      'date': '18 Aug 2026',
      'sla': 'Under 2 Hours',
      'status': 'In Review',
    },
    {
      'id': 'TCK-9842',
      'subject': 'Category Listing Commission Discount Request',
      'category': 'Catalog & Fees',
      'date': '12 Aug 2026',
      'sla': 'Resolved',
      'status': 'Resolved',
    },
    {
      'id': 'TCK-9710',
      'subject': 'Apna Express Logistics Pickup Address Update',
      'category': 'Logistics & Shipping',
      'date': '05 Aug 2026',
      'sla': 'Resolved',
      'status': 'Resolved',
    },
  ];

  void _showCreateTicketModal() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String category = 'Finance & Payouts';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Open Support Ticket to Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Ticket Category', isDense: true),
              items: const [
                DropdownMenuItem(value: 'Finance & Payouts', child: Text('Finance & Payouts')),
                DropdownMenuItem(value: 'Catalog & Fees', child: Text('Catalog & Fees')),
                DropdownMenuItem(value: 'Logistics & Shipping', child: Text('Logistics & Shipping')),
                DropdownMenuItem(value: 'Store Account Security', child: Text('Store Account Security')),
              ],
              onChanged: (v) {
                if (v != null) category = v;
              },
            ),
            const SizedBox(height: 8),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Subject Title', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: msgCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Detailed Description', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _tickets.insert(0, {
                    'id': 'TCK-${9900 + _tickets.length + 1}',
                    'subject': titleCtrl.text.trim(),
                    'category': category,
                    'date': '18 Aug 2026',
                    'sla': 'Under 2 Hours',
                    'status': 'In Review',
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support ticket submitted to Marketplace Governance!'), backgroundColor: Color(0xFF059669)),
                );
              }
            },
            child: const Text('Submit Ticket'),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _tickets.where((t) => t['status'] == 'In Review').length;
    final resolvedCount = _tickets.where((t) => t['status'] == 'Resolved').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Seller Support Tickets & Help Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Submit inquiries to marketplace governance, track resolution SLA, and manage open support tickets.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateTicketModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Open New Support Ticket', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildKpiBox('Open Help Tickets', '$openCount Active In Review', Icons.confirmation_number_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('Resolved Tickets', '$resolvedCount Tickets Resolved', Icons.check_circle_outline, const Color(0xFF059669)),
                  _buildKpiBox('Support SLA Speed', '< 1.8 Hours Avg SLA', Icons.speed_outlined, const Color(0xFF7C3AED)),
                  _buildKpiBox('Seller SLA Satisfaction', '99.4% SLA Rating', Icons.verified_user_outlined, const Color(0xFFB45309)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Tickets Table Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Marketplace Governance Support Tickets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Text('TICKET ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 4, child: Text('SUBJECT TITLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('SLA STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Rows
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tickets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final t = _tickets[index];
                    final bool isInReview = t['status'] == 'In Review';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(t['id']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                          Expanded(flex: 4, child: Text(t['subject']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
                          Expanded(flex: 2, child: Text(t['category']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                          Expanded(flex: 2, child: Text(t['date']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                          Expanded(flex: 2, child: Text(t['sla']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)))),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isInReview ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  t['status']!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isInReview ? const Color(0xFF2563EB) : const Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 4. Executive Seller KYC Identity Verification & Business Compliance Desk
class SellerKycVerificationSection extends StatelessWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerKycVerificationSection({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  Widget _buildKpiBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(BuildContext context, String docTitle, String number, String status, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF059669), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(docTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                      child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Document Ref Number: $number', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Re-upload modal opened for $docTitle.'), backgroundColor: const Color(0xFF2563EB)),
              );
            },
            icon: const Icon(Icons.upload_file, size: 14),
            label: const Text('Update Document', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Seller Identity KYC & Business Compliance Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Submit CNIC, FBR NTN tax registration, business bank proof, and monitor account verification tier.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verified Seller Badge Compliance Certificate loaded!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.verified, size: 14),
                label: const Text('Download KYC Pass', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildKpiBox('KYC Tier Status', 'Tier 1 Verified', Icons.verified_user_outlined, const Color(0xFF059669)),
                  _buildKpiBox('CNIC Identity', 'Verified Active', Icons.badge_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('FBR Tax Registration', 'NTN Verified', Icons.receipt_outlined, const Color(0xFFB45309)),
                  _buildKpiBox('Bank Verification', 'Disbursement Active', Icons.account_balance_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Documents List
          _buildDocCard(context, 'National Identity Card (CNIC)', '35202-****789-1', 'Verified & Approved', Icons.badge_outlined),
          _buildDocCard(context, 'FBR Business Tax Registration (NTN / STRN)', '7890123-4', 'Verified Active', Icons.receipt_outlined),
          _buildDocCard(context, 'Disbursement Bank Account Proof', 'PK88 MEZN **** 0607', 'Verified', Icons.account_balance_outlined),
        ],
      ),
    );
  }
}

