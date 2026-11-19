import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

class BuyerOrdersChatSection extends StatelessWidget {
  final AppStateProvider state;
  final double screenWidth;
  final VoidCallback onGoHome;

  const BuyerOrdersChatSection({
    super.key,
    required this.state,
    required this.screenWidth,
    required this.onGoHome,
  });

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required String time,
    required bool isDone,
    required bool isCurrent,
    required bool isLast,
  }) {
    final dotColor = isDone
        ? const Color(0xFF16A34A)
        : (isCurrent ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  if (isCurrent)
                    BoxShadow(color: dotColor.withOpacity(0.4), blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                color: isDone ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isDone || isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isDone || isCurrent ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingTimeline() {
    return Column(
      children: [
        _buildTimelineStep(
          title: 'Order Placed & Payment Verified',
          subtitle: 'Order #ORD-2026-8891 placed via Cash on Delivery',
          time: '12 Aug, 10:30 AM',
          isDone: true,
          isCurrent: false,
          isLast: false,
        ),
        _buildTimelineStep(
          title: 'Packed & Processed by Seller',
          subtitle: 'Store warehouse verified inventory and packed items',
          time: '12 Aug, 02:15 PM',
          isDone: true,
          isCurrent: false,
          isLast: false,
        ),
        _buildTimelineStep(
          title: 'Handed to Courier (TCS Express)',
          subtitle: 'Tracking ID: TCS-99482019-PK',
          time: '13 Aug, 09:00 AM',
          isDone: true,
          isCurrent: true,
          isLast: false,
        ),
        _buildTimelineStep(
          title: 'Out for Delivery',
          subtitle: 'Rider assigned for doorstep delivery',
          time: 'Pending',
          isDone: false,
          isCurrent: false,
          isLast: false,
        ),
        _buildTimelineStep(
          title: 'Delivered',
          subtitle: 'Package signed and delivered to customer',
          time: 'Pending',
          isDone: false,
          isCurrent: false,
          isLast: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Utility Bar
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/buyer/order-tracking'),
                      child: const Text('Track Order Status', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/buyer/chat-qa'),
                      child: const Text('Live Support Chat', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Header Row
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: onGoHome,
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: const Color(0xFF004D40), borderRadius: BorderRadius.circular(6)),
                            child: const Center(child: Icon(Icons.storefront, color: Colors.white, size: 18)),
                          ),
                          const SizedBox(width: 8),
                          const Text('ELEGANT MARKETPLACE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/buyer/chat-qa'),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
                      label: const Text('Seller Live Chat', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004D40),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Body Content (Timeline & Active Orders)
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1280),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Orders & Delivery Tracking', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Order #ORD-2026-8891', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(6)),
                              child: const Text('In Transit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildTrackingTimeline(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
