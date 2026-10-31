import 'package:flutter/material.dart';

class BuyerRewardsLoyaltyScreen extends StatefulWidget {
  const BuyerRewardsLoyaltyScreen({super.key});

  @override
  State<BuyerRewardsLoyaltyScreen> createState() => _BuyerRewardsLoyaltyScreenState();
}

class _BuyerRewardsLoyaltyScreenState extends State<BuyerRewardsLoyaltyScreen> {
  int _userRewardCoins = 2450;
  int _checkInStreak = 4; // Day 4
  bool _isCheckedInToday = false;

  final List<Map<String, dynamic>> _streakDays = [
    {'day': 'Day 1', 'coins': 10, 'claimed': true},
    {'day': 'Day 2', 'coins': 20, 'claimed': true},
    {'day': 'Day 3', 'coins': 30, 'claimed': true},
    {'day': 'Day 4', 'coins': 40, 'claimed': true},
    {'day': 'Day 5', 'coins': 50, 'claimed': false},
    {'day': 'Day 6', 'coins': 75, 'claimed': false},
    {'day': 'Day 7', 'coins': 150, 'claimed': false},
  ];

  @override
  Widget build(BuildContext context) {
    final int redeemableCash = (_userRewardCoins / 10).floor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty Rewards & Coin Center'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gold VIP Loyalty Tier Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFDB913), Color(0xFFE65100)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                          SizedBox(width: 8),
                          Text('GOLD VIP MEMBER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
                        child: const Text('2x Points Boost Active', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available Reward Coins', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.monetization_on, color: Colors.white, size: 22),
                              const SizedBox(width: 6),
                              Text('$_userRewardCoins Coins', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.swap_horiz, size: 14),
                        label: Text('Redeem Rs. $redeemableCash', style: const TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFE65100),
                        ),
                        onPressed: () {
                          if (_userRewardCoins >= 100) {
                            setState(() {
                              _userRewardCoins -= 1000;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('1,000 Coins Converted to Rs. 100 Shopping Wallet Cash!')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Gamified 7-Day Daily Check-In Streak Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_month, color: Color(0xFF004D40)),
                            SizedBox(width: 8),
                            Text('Daily Check-In Streak (4 Days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCheckedInToday ? Colors.grey : const Color(0xFF004D40),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isCheckedInToday
                              ? null
                              : () {
                                  setState(() {
                                    _isCheckedInToday = true;
                                    _userRewardCoins += 50;
                                    _streakDays[4]['claimed'] = true;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Day 5 Claimed! +50 Coins Added to your Account.')),
                                  );
                                },
                          child: Text(_isCheckedInToday ? 'Claimed ✓' : 'Check In (+50)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 7 Days Grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _streakDays.map((d) {
                        final bool claimed = d['claimed'] as bool;
                        return Container(
                          width: 42,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: claimed ? const Color(0xFF004D40) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: claimed ? const Color(0xFF004D40) : Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Text(d['day'] as String, style: TextStyle(fontSize: 9, color: claimed ? Colors.white70 : Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Icon(Icons.monetization_on, size: 14, color: claimed ? const Color(0xFFFDB913) : Colors.grey),
                              const SizedBox(height: 2),
                              Text('+${d['coins']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: claimed ? Colors.white : Colors.black)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Lucky Spin Wheel Mini-Game Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0xFFFDB913),
                      child: Icon(Icons.casino, color: Colors.black, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lucky Spin-the-Wheel Game', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('1 Free Spin Available Today! Win up to Rs. 1,000 Voucher.', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004D40),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _showSpinWheelDialog(context),
                      child: const Text('Spin Now'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Gold VIP Perks List
            const Text('Your Exclusive Gold VIP Perks:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildPerkTile('Free Priority Shipping', 'Free doorstep shipping on orders over Rs. 1,000', Icons.local_shipping),
            _buildPerkTile('2x Coin Multiplier', 'Earn double coins on all apparel & fashion orders', Icons.bolt),
            _buildPerkTile('VIP Customer Support Desk', 'Dedicated WhatsApp support hotline for Gold buyers', Icons.headset_mic),
            _buildPerkTile('Free Doorstep Return Pickup', 'Zero pickup fee for returns and exchanges', Icons.replay),
          ],
        ),
      ),
    );
  }

  Widget _buildPerkTile(String title, String desc, IconData icon) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF004D40).withOpacity(0.1),
          child: Icon(icon, color: const Color(0xFF004D40), size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        trailing: const Icon(Icons.check_circle, color: Colors.green, size: 18),
      ),
    );
  }

  void _showSpinWheelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.stars, color: Color(0xFFFDB913), size: 50),
            SizedBox(height: 8),
            Text('🎉 Congratulations!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You won a Rs. 500 Discount Voucher!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
            SizedBox(height: 6),
            Text('Voucher Code SPIN500 has been credited to your coupon wallet.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _userRewardCoins += 100);
            },
            child: const Text('Claim Reward'),
          ),
        ],
      ),
    );
  }
}
