import 'package:flutter/material.dart';

class ChatMessageItem {
  final String sender; // 'buyer', 'seller', 'ai'
  final String text;
  final String time;
  final String? translatedText;
  final Map<String, dynamic>? attachment;

  ChatMessageItem({
    required this.sender,
    required this.text,
    required this.time,
    this.translatedText,
    this.attachment,
  });
}

class BuyerChatQaScreen extends StatefulWidget {
  const BuyerChatQaScreen({super.key});

  @override
  State<BuyerChatQaScreen> createState() => _BuyerChatQaScreenState();
}

class _BuyerChatQaScreenState extends State<BuyerChatQaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  bool _showTranslation = false;

  final List<ChatMessageItem> _messages = [
    ChatMessageItem(
      sender: 'seller',
      text: 'Hello! Welcome to Gul Ahmed Official Store. How can we help you today?',
      translatedText: 'سلام! گل احمد آفیشل اسٹور میں خوش آمدید۔ آج ہم آپ کی کیا مدد کر سکتے ہیں؟',
      time: '11:30 AM',
    ),
    ChatMessageItem(
      sender: 'buyer',
      text: 'Hi, is the Emerald Green Lawn 3-Piece suit available in size M?',
      translatedText: 'کیا زمردی سبز لان 3-پیس سوٹ سائز M میں دستیاب ہے؟',
      time: '11:31 AM',
    ),
    ChatMessageItem(
      sender: 'ai',
      text: '🤖 AI Assistant: Yes! 14 units of Size M are in stock in Lahore Warehouse.',
      time: '11:31 AM',
      attachment: {
        'title': 'Embroidered Lawn 3-Piece Suit',
        'price': 'Rs. 3,500',
        'stock': '14 In Stock',
        'icon': Icons.checkroom,
      },
    ),
    ChatMessageItem(
      sender: 'seller',
      text: 'Here is an exclusive Rs. 200 Store Voucher for your purchase!',
      translatedText: 'آپ کی خریداری کے لیے یہاں ایک خصوصی 200 روپے کا اسٹور واؤچر ہے!',
      time: '11:32 AM',
      attachment: {
        'title': 'Store Voucher: GUL200',
        'discount': 'Rs. 200 OFF',
        'validity': 'Valid for 24 Hours',
        'icon': Icons.confirmation_number,
      },
    ),
  ];

  final List<Map<String, String>> _publicQaList = [
    {
      'question': 'Q: Does the fabric color fade after washing?',
      'askedBy': 'Ali K. (Verified Buyer)',
      'answer': 'A: No, our lawn suits use 100% fast dye reactive colors. Color is guaranteed non-fade.',
      'answeredBy': 'Gul Ahmed Official (Seller)',
    },
    {
      'question': 'Q: What is the exact delivery time to Karachi?',
      'askedBy': 'Sara M.',
      'answer': 'A: Karachi orders ship from our Hub via TCS Express and arrive in 24 to 48 hours.',
      'answeredBy': 'Gul Ahmed Official (Seller)',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
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
                children: const [
                  Text('Gul Ahmed Store Chat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Replies in ~5 mins | 24/7 AI Online', style: TextStyle(fontSize: 10, color: Colors.white70)),
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
                  Tab(text: 'Direct Seller Chat & AI'),
                  Tab(text: 'Public Product Q&A'),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_showTranslation ? Icons.g_translate : Icons.translate, color: _showTranslation ? const Color(0xFFFDB913) : Colors.white),
            onPressed: () => setState(() => _showTranslation = !_showTranslation),
            tooltip: 'Toggle Urdu / Roman Urdu Translation',
          ),
        ],
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
              // Tab 1: Direct Seller Chat & AI Assistant
          Column(
            children: [
              // Chat Message List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final bool isBuyer = msg.sender == 'buyer';
                    final bool isAi = msg.sender == 'ai';

                    return Align(
                      alignment: isBuyer ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isBuyer
                              ? const Color(0xFF004D40)
                              : isAi
                                  ? Colors.teal.shade50
                                  : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                          border: isAi ? Border.all(color: Colors.teal) : Border.all(color: Colors.transparent),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _showTranslation && msg.translatedText != null ? msg.translatedText! : msg.text,
                              style: TextStyle(
                                color: isBuyer ? Colors.white : Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Attachment Card if present
                            if (msg.attachment != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(msg.attachment!['icon'] as IconData, color: const Color(0xFF004D40)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(msg.attachment!['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
                                          Text(msg.attachment!['price'] ?? msg.attachment!['discount'] as String, style: const TextStyle(fontSize: 10, color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 4),
                            Text(msg.time, style: TextStyle(fontSize: 9, color: isBuyer ? Colors.white70 : Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Quick Reply Chips
              Container(
                height: 36,
                color: Colors.grey.shade100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildQuickReplyChip('Is size M in stock?'),
                    _buildQuickReplyChip('When will my order ship?'),
                    _buildQuickReplyChip('Can I get a discount?'),
                    _buildQuickReplyChip('Is cash on delivery available?'),
                  ],
                ),
              ),

              // Message Input Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.grey),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Attaching Product / Voucher Card...')),
                        );
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type your question to Seller or AI...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                      onPressed: () {
                        if (_messageController.text.isNotEmpty) {
                          setState(() {
                            _messages.add(ChatMessageItem(
                              sender: 'buyer',
                              text: _messageController.text,
                              time: 'Just now',
                            ));
                          });
                          _messageController.clear();
                        }
                      },
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

  Widget _buildQuickReplyChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11)),
        onPressed: () => setState(() => _messageController.text = text),
      ),
    );
  }
}
