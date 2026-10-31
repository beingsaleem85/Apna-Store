import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/app_state_provider.dart';

class RealChatRoom {
  final String id;
  final String customerName;
  final String lastMsg;
  final DateTime updatedAt;
  final String? orderId;

  RealChatRoom({
    required this.id,
    required this.customerName,
    required this.lastMsg,
    required this.updatedAt,
    this.orderId,
  });
}

class RealChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isSeller;

  RealChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isSeller,
  });
}

class SellerCustomerChatScreen extends StatefulWidget {
  const SellerCustomerChatScreen({super.key});

  @override
  State<SellerCustomerChatScreen> createState() => _SellerCustomerChatScreenState();
}

class _SellerCustomerChatScreenState extends State<SellerCustomerChatScreen> {
  final List<RealChatRoom> _rooms = [];
  final List<RealChatMessage> _messages = [];
  RealChatRoom? _selectedRoom;
  bool _isLoadingRooms = true;
  bool _isLoadingMessages = false;
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchChatRooms();
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatRooms() async {
    setState(() => _isLoadingRooms = true);
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
          _rooms.clear();
          _isLoadingRooms = false;
        });
        return;
      }

      final data = await Supabase.instance.client
          .from('chat_rooms')
          .select('id, buyer_user_id, order_id, created_at, profiles:buyer_user_id(full_name)')
          .eq('seller_store_id', storeId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _rooms.clear();
          for (final r in (data as List)) {
            final profile = r['profiles'] is Map ? r['profiles'] : null;
            final buyerName = profile != null && profile['full_name'] != null
                ? profile['full_name'].toString()
                : 'Customer (${r['buyer_user_id']?.toString().substring(0, 6) ?? 'Buyer'})';

            _rooms.add(RealChatRoom(
              id: r['id'].toString(),
              customerName: buyerName,
              lastMsg: 'Inquiry on Order ${r['order_id'] ?? ''}',
              updatedAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
              orderId: r['order_id']?.toString(),
            ));
          }
          if (_rooms.isNotEmpty) {
            _selectedRoom = _rooms.first;
            _fetchMessages(_selectedRoom!.id);
          }
          _isLoadingRooms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRooms = false);
    }
  }

  Future<void> _fetchMessages(String roomId) async {
    setState(() => _isLoadingMessages = true);
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final data = await Supabase.instance.client
          .from('chat_messages')
          .select('id, room_id, sender_id, message_text, created_at')
          .eq('room_id', roomId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages.clear();
          for (final m in (data as List)) {
            final sender = m['sender_id']?.toString() ?? '';
            _messages.add(RealChatMessage(
              id: m['id'].toString(),
              senderId: sender,
              text: (m['message_text'] ?? '').toString(),
              createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
              isSeller: sender == currentUserId,
            ));
          }
          _isLoadingMessages = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _selectedRoom == null) return;
    _msgController.clear();

    try {
      await Supabase.instance.client.rpc(
        'send_chat_message',
        params: {
          'p_room_id': _selectedRoom!.id,
          'p_message_text': text,
        },
      );
      await _fetchMessages(_selectedRoom!.id);
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
      appBar: AppBar(
        title: const Text('Customer Messages & Inquiries'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchChatRooms,
            tooltip: 'Refresh Chats',
          ),
        ],
      ),
      body: _isLoadingRooms
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 54, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No Customer Inquiries Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text(
                          'When buyers ask questions about your products or orders, they will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : Row(
                  children: [
                    // Sidebar
                    SizedBox(
                      width: 320,
                      child: Card(
                        margin: EdgeInsets.zero,
                        shape: const RoundedRectangleBorder(),
                        child: ListView.separated(
                          itemCount: _rooms.length,
                          separatorBuilder: (ctx, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final room = _rooms[index];
                            final isSelected = _selectedRoom?.id == room.id;

                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: const Color(0xFF004D40).withOpacity(0.08),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF004D40),
                                child: Text(
                                  room.customerName.isNotEmpty ? room.customerName[0].toUpperCase() : 'C',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(room.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(
                                room.orderId != null ? 'Order: ${room.orderId}' : 'Product Inquiry',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              onTap: () {
                                setState(() => _selectedRoom = room);
                                _fetchMessages(room.id);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),

                    // Chat Area
                    Expanded(
                      child: _selectedRoom == null
                          ? const Center(child: Text('Select a conversation to start chatting.'))
                          : Column(
                              children: [
                                // Chat header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  color: Colors.grey.shade100,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person, color: Color(0xFF004D40)),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedRoom!.customerName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),

                                // Messages
                                Expanded(
                                  child: _isLoadingMessages
                                      ? const Center(child: CircularProgressIndicator())
                                      : _messages.isEmpty
                                          ? const Center(
                                              child: Text('No messages yet in this inquiry. Reply below.', style: TextStyle(color: Colors.grey)),
                                            )
                                          : ListView.builder(
                                              padding: const EdgeInsets.all(16),
                                              itemCount: _messages.length,
                                              itemBuilder: (context, index) {
                                                final msg = _messages[index];
                                                final isMe = msg.isSeller;

                                                return Align(
                                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                                  child: Container(
                                                    margin: const EdgeInsets.only(bottom: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                    constraints: const BoxConstraints(maxWidth: 400),
                                                    decoration: BoxDecoration(
                                                      color: isMe ? const Color(0xFF004D40) : Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      msg.text,
                                                      style: TextStyle(
                                                        color: isMe ? Colors.white : Colors.black87,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                ),

                                // Input bar
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _msgController,
                                          decoration: const InputDecoration(
                                            hintText: 'Type your reply...',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          ),
                                          onSubmitted: (_) => _sendMessage(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.send, color: Color(0xFF004D40)),
                                        onPressed: _sendMessage,
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
}
