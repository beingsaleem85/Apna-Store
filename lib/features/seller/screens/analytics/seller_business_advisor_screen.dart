import 'package:flutter/material.dart';

class SellerBusinessAdvisorScreen extends StatefulWidget {
  const SellerBusinessAdvisorScreen({super.key});

  @override
  State<SellerBusinessAdvisorScreen> createState() => _SellerBusinessAdvisorScreenState();
}

class _SellerBusinessAdvisorScreenState extends State<SellerBusinessAdvisorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Business Advisor & Analytics'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading Business Diagnostic Report PDF...')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Traffic & Conversion Funnel Telemetry Card
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Store Pageviews', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('15,200', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Unique Visitors', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('4,100', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFDB913))),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Cart Additions', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('820', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Conversion Rate', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('3.4%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Customer Cities Breakdown
            const Text('Geographic Buyer Cities Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.location_city, color: Color(0xFF004D40)),
                      title: Text('Lahore Hub', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('45% (Rs. 180,000)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                    ),
                    Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.location_city, color: Colors.amber),
                      title: Text('Karachi Hub', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('30% (Rs. 120,000)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                    ),
                    Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.location_city, color: Colors.purple),
                      title: Text('Islamabad Hub', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('15% (Rs. 60,000)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Export Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Export Business Metrics CSV'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exporting CSV File...')),
                    );
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generate Monthly Executive PDF'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generating Monthly PDF Report...')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
