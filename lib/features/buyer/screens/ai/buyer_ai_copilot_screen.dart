import 'package:flutter/material.dart';

class CopilotMessage {
  final String sender; // 'user', 'ai'
  final String text;
  final List<Map<String, dynamic>>? recommendedProducts;

  CopilotMessage({required this.sender, required this.text, this.recommendedProducts});
}

class BuyerAiCopilotScreen extends StatefulWidget {
  const BuyerAiCopilotScreen({super.key});

  @override
  State<BuyerAiCopilotScreen> createState() => _BuyerAiCopilotScreenState();
}

class _BuyerAiCopilotScreenState extends State<BuyerAiCopilotScreen> {
  final TextEditingController _promptController = TextEditingController();
  String _currentLanguage = 'Urdu Script (اردو)';
  String _selectedTheme = '🌙 Ramzan Mubarak (Green)';
  String _selectedCity = 'Lahore';

  final List<CopilotMessage> _chatHistory = [
    CopilotMessage(
      sender: 'ai',
      text: '🤖 Assalam-o-Alaikum! I am your ApnaStore AI Shopping Copilot. Tell me your budget or what you are looking for today!',
    ),
    CopilotMessage(
      sender: 'user',
      text: 'عید کے لیے 4,000 روپے کے اندر زبردست لان کا سوٹ تجویز کریں۔',
    ),
    CopilotMessage(
      sender: 'ai',
      text: '🤖 Based on your budget of Rs. 4,000 and preference for Lawn Suits, here are the top 2 trending recommendations with free shipping:',
      recommendedProducts: [
        {
          'title': 'Embroidered Lawn 3-Piece Suit',
          'store': 'Gul Ahmed Official',
          'price': 'Rs. 3,500',
          'rating': '4.8 ★',
          'icon': Icons.checkroom,
        },
        {
          'title': 'Printed Floral 3-Piece Lawn Collection',
          'store': 'Khaadi Official',
          'price': 'Rs. 3,850',
          'rating': '4.9 ★',
          'icon': Icons.style,
        },
      ],
    ),
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Color(0xFFFDB913)),
            SizedBox(width: 8),
            Text('AI Shopping Copilot & Pakistan Hub'),
          ],
        ),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: Column(
        children: [
          // Localization & City Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF004D40), size: 18),
                    const SizedBox(width: 4),
                    DropdownButton<String>(
                      value: _selectedCity,
                      underline: const SizedBox(),
                      items: ['Lahore', 'Karachi', 'Islamabad', 'Peshawar', 'Quetta', 'Multan', 'Faisalabad']
                          .map((c) => DropdownMenuItem(value: c, child: Text('City: $c', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedCity = val!),
                    ),
                  ],
                ),
                DropdownButton<String>(
                  value: _currentLanguage,
                  underline: const SizedBox(),
                  items: ['English', 'Urdu Script (اردو)', 'Roman Urdu']
                      .map((lang) => DropdownMenuItem(value: lang, child: Text(lang, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))))
                      .toList(),
                  onChanged: (val) => setState(() => _currentLanguage = val!),
                ),
              ],
            ),
          ),

          // Theme Switcher Ticker Bar
          Container(
            height: 34,
            color: Colors.amber.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.palette, size: 14, color: Colors.brown),
                const SizedBox(width: 6),
                Text('Active Theme: $_selectedTheme', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown)),
              ],
            ),
          ),

          // AI Chat Stream List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _chatHistory.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final msg = _chatHistory[index];
                final bool isUser = msg.sender == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF004D40) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                      border: isUser ? Border.all(color: Colors.transparent) : Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            fontSize: 13,
                          ),
                        ),

                        // Recommended Products Cards if present
                        if (msg.recommendedProducts != null) ...[
                          const SizedBox(height: 12),
                          Column(
                            children: msg.recommendedProducts!.map((p) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF004D40).withOpacity(0.1),
                                      child: Icon(p['icon'] as IconData, color: const Color(0xFF004D40)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                          Text('${p['store']} | ${p['rating']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          Text(p['price'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40), fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Item added to cart via AI Copilot!')),
                                        );
                                      },
                                      child: const Text('Buy Now', style: TextStyle(fontSize: 10)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Voice / Prompt Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.mic, color: Color(0xFF004D40)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Listening... Speak your prompt in Urdu or English.')),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      hintText: 'Ask AI Copilot (e.g. Find shoes under Rs. 3,000)...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () {
                    if (_promptController.text.isNotEmpty) {
                      setState(() {
                        _chatHistory.add(CopilotMessage(sender: 'user', text: _promptController.text));
                        _chatHistory.add(CopilotMessage(
                          sender: 'ai',
                          text: '🤖 Searching catalog for "${_promptController.text}" in $_selectedCity zone...',
                        ));
                      });
                      _promptController.clear();
                    }
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
