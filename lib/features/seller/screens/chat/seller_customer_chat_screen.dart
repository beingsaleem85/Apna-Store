import 'package:flutter/material.dart';

class ChatCustomer {
  final String id;
  final String name;
  final String lastMsg;
  final String time;
  final int unread;

  ChatCustomer({
    required this.id,
    required this.name,
    required this.lastMsg,
    required this.time,
    required this.unread,
  });
}

class SellerCustomerChatScreen extends StatefulWidget {
  const SellerCustomerChatScreen({super.key});

  @override
  State<SellerCustomerChatScreen> createState() => _SellerCustomerChatScreenState();
}

class _SellerCustomerChatScreenState extends State<SellerCustomerChatScreen> {
  bool _aiAutoReplyEnabled = true;
  ChatCustomer? _selectedCustomer;
  final TextEditingController _msgController = TextEditingController();

  final List<ChatCustomer> _customers = [
    ChatCustomer(id: 'CUST-1', name: 'Sana Ahmed', lastMsg: 'Is the medium size available in black?', time: '10:45 AM', unread: 2),
    ChatCustomer(id: 'CUST-2', name: 'Hamza Khan', lastMsg: 'When will my order be dispatched?', time: '09:30 AM', unread: 0),
    ChatCustomer(id: 'CUST-3', name: 'Ayesha Tariq', lastMsg: 'Can you send a discount voucher?', time: 'Yesterday', unread: 1),
  ];

  final List<Map<String, String>> _messages = [
    {'sender': 'customer', 'text': 'Hi! Is the medium size available in black color?'},
    {'sender': 'seller', 'text': 'Hello Sana! Yes, black medium is in stock and ready to ship.'},
    {'sender': 'customer', 'text': 'Great! What is the estimated delivery time to Lahore?'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCustomer = _customers.first;
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Instant Chat & AI Assistant'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          Row(
            children: [
              const Text('AI Auto-Reply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(
                value: _aiAutoReplyEnabled,
                activeColor: const Color(0xFFFDB913),
                onChanged: (val) {
                  setState(() => _aiAutoReplyEnabled = val);
                },
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          // Customer Conversations Sidebar
          SizedBox(
            width: 300,
            child: Card(
              margin: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(),
              child: ListView.separated(
                itemCount: _customers.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final c = _customers[index];
                  final isSelected = _selectedCustomer?.id == c.id;

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: const Color(0xFF004D40).withOpacity(0.1),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF004D40),
                      child: Text(c.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(c.time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    subtitle: Text(c.lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                    onTap: () {
                      setState(() => _selectedCustomer = c);
                    },
                  );
                },
              ),
            ),
          ),

          // Active Chat Thread View
          Expanded(
            child: Column(
              children: [
                // Chat Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.grey.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Chatting with: ${_selectedCustomer?.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.shopping_bag, size: 14),
                            label: const Text('Send Product Card', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product Card Sent in Chat!')));
                            },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.confirmation_num, size: 14),
                            label: const Text('Send Voucher', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('10% OFF Voucher Sent in Chat!')));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Messages Body
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isMe = m['sender'] == 'seller';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF004D40) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            m['text']!,
                            style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 13),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Quick Response Template Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _buildQuickChip('Product in stock!'),
                      _buildQuickChip('Delivery: 2-3 Days'),
                      _buildQuickChip('Check Size Chart'),
                      _buildQuickChip('Dispatched Today'),
                    ],
                  ),
                ),

                // Input Bar
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          decoration: const InputDecoration(
                            hintText: 'Type your message...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF004D40)),
                        onPressed: () {
                          if (_msgController.text.isNotEmpty) {
                            setState(() {
                              _messages.add({'sender': 'seller', 'text': _msgController.text});
                              _msgController.clear();
                            });
                          }
                        },
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
        label: Text(text, style: const TextStyle(fontSize: 10)),
        onPressed: () {
          setState(() {
            _messages.add({'sender': 'seller', 'text': text});
          });
        },
      ),
    );
  }
}
