import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BuyerChatMessageItem {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isBuyer;

  BuyerChatMessageItem({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isBuyer,
  });
}

class BuyerChatQaScreen extends StatefulWidget {
  final String? initialRoomId;
  const BuyerChatQaScreen({super.key, this.initialRoomId});

  @override
  State<BuyerChatQaScreen> createState() => _BuyerChatQaScreenState();
}

class _BuyerChatQaScreenState extends State<BuyerChatQaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();

  String? _activeRoomId;
  String _sellerStoreName = 'Seller Support';
  final List<BuyerChatMessageItem> _messages = [];
  bool _isLoading = true;

  final List<Map<String, String>> _publicQaList = [
    {
      'question': 'Q: Does the fabric color fade after washing?',
      'askedBy': 'Verified Buyer',
      'answer': 'A: No, products from verified sellers use reactive fast dyes.',
      'answeredBy': 'Store Support',
    },
    {
      'question': 'Q: What is the delivery time across Pakistan?',
      'askedBy': 'Customer Inquiry',
      'answer': 'A: Major cities arrive in 24 to 48 hours via TCS / Leopard Courier.',
      'answeredBy': 'Logistics Desk',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeChat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      if (widget.initialRoomId != null) {
        _activeRoomId = widget.initialRoomId;
      } else {
        // Query latest chat room for this buyer
        final rooms = await Supabase.instance.client
            .from('chat_rooms')
            .select('id, seller_store_id, seller_stores:seller_store_id(name)')
            .eq('buyer_user_id', user.id)
            .order('created_at', ascending: false)
            .limit(1);

        if (rooms.isNotEmpty) {
          _activeRoomId = rooms.first['id'].toString();
          final store = rooms.first['seller_stores'];
          if (store is Map && store['name'] != null) {
            _sellerStoreName = store['name'].toString();
          }
        }
      }

      if (_activeRoomId != null) {
        await _fetchMessages(_activeRoomId!);
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMessages(String roomId) async {
    try {
      final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';
      final data = await Supabase.instance.client
          .from('chat_messages')
          .select('id, sender_id, message_text, created_at')
          .eq('room_id', roomId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages.clear();
          for (final row in (data as List)) {
            final sender = (row['sender_id'] ?? '').toString();
            _messages.add(BuyerChatMessageItem(
              id: row['id'].toString(),
              senderId: sender,
              text: (row['message_text'] ?? '').toString(),
              createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
              isBuyer: sender == currentUid,
            ));
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to chat with sellers.')),
      );
      return;
    }

    _messageController.clear();

    try {
      // If no room exists, create one with the first active store
      if (_activeRoomId == null) {
        final stores = await Supabase.instance.client
            .from('seller_stores')
            .select('id, name')
            .eq('is_approved', true)
            .limit(1);

        if (stores.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active store available to message.')),
            );
          }
          return;
        }

        final storeId = stores.first['id'].toString();
        _sellerStoreName = stores.first['name'] ?? 'Store Support';

        final res = await Supabase.instance.client.rpc(
          'create_chat_room',
          params: {
            'p_seller_store_id': storeId,
            'p_product_id': null,
            'p_order_id': null,
          },
        );

        _activeRoomId = res is Map ? res['room_id']?.toString() : res?.toString();
      }

      if (_activeRoomId != null) {
        await Supabase.instance.client.rpc(
          'send_chat_message',
          params: {
            'p_room_id': _activeRoomId!,
            'p_message_text': text,
          },
        );
        await _fetchMessages(_activeRoomId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        centerTitle: true,
        title: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white24,
                radius: 16,
                child: Icon(Icons.store, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_sellerStoreName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Text('Verified Merchant Direct Chat', style: TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFDB913),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Direct Seller Chat'),
                  Tab(text: 'Public Product Q&A'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Direct Seller Chat
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        // Messages List
                        Expanded(
                          child: _messages.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                                        SizedBox(height: 12),
                                        Text('No messages yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        SizedBox(height: 4),
                                        Text('Ask the seller questions about sizing, delivery, or custom orders.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _messages.length,
                                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final msg = _messages[index];
                                    final isBuyer = msg.isBuyer;

                                    return Align(
                                      alignment: isBuyer ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 400),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isBuyer ? const Color(0xFF004D40) : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              msg.text,
                                              style: TextStyle(
                                                color: isBuyer ? Colors.white : Colors.black87,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: isBuyer ? Colors.white70 : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // Message Input Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: const InputDecoration(
                                    hintText: 'Type your message to seller...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                icon: const Icon(Icons.send),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF004D40),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _sendMessage,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

              // Tab 2: Public Product Q&A
              ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _publicQaList.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final qa = _publicQaList[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(qa['question']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Asked by ${qa['askedBy']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const Divider(height: 16),
                          Text(qa['answer']!, style: const TextStyle(fontSize: 12, color: Color(0xFF004D40))),
                          Text('Answered by ${qa['answeredBy']}', style: const TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
