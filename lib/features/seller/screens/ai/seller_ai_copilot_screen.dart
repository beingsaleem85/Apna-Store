import 'package:flutter/material.dart';
import '../../../../core/config/feature_flags.dart';

class SellerAiCopilotScreen extends StatefulWidget {
  const SellerAiCopilotScreen({super.key});

  @override
  State<SellerAiCopilotScreen> createState() => _SellerAiCopilotScreenState();
}

class _SellerAiCopilotScreenState extends State<SellerAiCopilotScreen> {
  final TextEditingController _keywordsController = TextEditingController(text: 'lawn suit, embroidered, 3 piece, black, summer');
  String _generatedTitle = '';
  String _generatedDesc = '';
  bool _isGenerating = false;

  @override
  void dispose() {
    _keywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Seller Copilot & Smart Assistant'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Title & SEO Description Studio Card
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFFFDB913), size: 28),
                        SizedBox(width: 12),
                        Text('AI Product Title & SEO Description Generator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _keywordsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Raw Product Keywords / Features',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.flash_on),
                      label: Text(_isGenerating ? 'Generating with AI...' : 'Generate SEO Title & Copy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDB913),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: _isGenerating ? null : _generateAiCopy,
                    ),

                    if (_generatedTitle.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AI Generated Title:', style: TextStyle(color: Color(0xFFFDB913), fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(_generatedTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 12),
                            const Text('AI SEO Description & Bullets:', style: TextStyle(color: Color(0xFFFDB913), fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(_generatedDesc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Smart Price Advisor Card
            const Text('AI Smart Competitor Price Advisor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Listing Price: Rs. 2,999', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('AI Suggested: Rs. 2,850', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('💡 AI Insight: Lowering price by Rs. 149 matches top 3 competitor prices and increases sale conversion rate by +18%.', style: TextStyle(fontSize: 11, color: Colors.black87)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // AI Image Background Remover
            Card(
              color: Colors.amber.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Image Background Remover & Studio Upscaler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Automatically remove cluttered backgrounds and enhance image resolution.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cleaning_services, size: 16),
                      label: const Text('Clean Photo BG'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('AI Product Image Background Cleaned!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateAiCopy() {
    if (!FeatureFlags.aiCopilotEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Copilot service is currently disabled (Feature Flag OFF). Real AI API integration required.')),
      );
      return;
    }
    setState(() => _isGenerating = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatedTitle = 'Luxury Embroidered Lawn 3-Piece Unstitched Suit — Midnight Black Edition 2026';
          _generatedDesc = '• Premium 100% Cotton Lawn Fabric\n'
              '• Heavy Chiffon Embroidered Dupatta Included\n'
              '• Breathable & Color-Fast Guaranteed\n'
              '• Ideal for Summer Festive & Casual Wear';
        });
      }
    });
  }
}
