import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF475569))),
      ],
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2563EB).withOpacity(0.35),
          const Color(0xFF2563EB).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(size.width * 0.15, size.height * 0.4, size.width * 0.25, size.height * 0.6, size.width * 0.35, size.height * 0.35);
    path.cubicTo(size.width * 0.45, size.height * 0.5, size.width * 0.55, size.height * 0.65, size.width * 0.68, size.height * 0.2);
    path.cubicTo(size.width * 0.8, size.height * 0.4, size.width * 0.9, size.height * 0.3, size.width, size.height * 0.15);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;

    // Packed
    paint.color = const Color(0xFF0D9488);
    canvas.drawArc(rect, -1.57, 1.8, false, paint);

    // Shipped
    paint.color = const Color(0xFF2563EB);
    canvas.drawArc(rect, 0.3, 1.4, false, paint);

    // Delivered
    paint.color = const Color(0xFF059669);
    canvas.drawArc(rect, 1.8, 1.6, false, paint);

    // Pending
    paint.color = const Color(0xFFF59E0B);
    canvas.drawArc(rect, 3.5, 0.8, false, paint);

    // Returned
    paint.color = const Color(0xFFEF4444);
    canvas.drawArc(rect, 4.4, 0.6, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SellerDashboardOverview extends StatelessWidget {
  final AppStateProvider state;
  final AppStore store;
  final ValueChanged<String> onSelectSection;

  const SellerDashboardOverview({
    super.key,
    required this.state,
    required this.store,
    required this.onSelectSection,
  });

  Widget _buildOverviewCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(fontSize: 20, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductRow(String name, String oldPrice, String price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          oldPrice,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough),
        ),
        const SizedBox(width: 6),
        Text(
          price,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
        ),
      ],
    );
  }

  Widget _buildDashboardLeftCol(List<AppOrder> orders, List<AppProduct> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Revenue Chart Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Revenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: const Text('Daily', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: const Text('Weekly', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Text('Monthly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                width: double.infinity,
                child: CustomPaint(
                  painter: _RevenueChartPainter(),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mar 8', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Text('May 15', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Text('Nov 17', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Text('Nov 23', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Text('Nov 23', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Text('Frr 25', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Text('Nor 25', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Best-selling products
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Best-selling products', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    if (products.isNotEmpty)
                      ...products.take(4).map((p) {
                        final val = double.tryParse(p.price) ?? 3500.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildProductRow(p.name, 'PKR ${(val * 1.1).toInt()}', 'PKR ${val.toInt()}'),
                        );
                      })
                    else ...[
                      _buildProductRow('Embroidered Cotton Kurta', 'PKR 3,500', 'PKR 3,500'),
                      const SizedBox(height: 10),
                      _buildProductRow('Embroidered Cotton Kurta', 'PKR 3,500', 'PKR 2,900'),
                      const SizedBox(height: 10),
                      _buildProductRow('Green Toner Kurta', 'PKR 3,600', 'PKR 3,500'),
                      const SizedBox(height: 10),
                      _buildProductRow('Embroidered Cotton Kurta', 'PKR 3,600', 'PKR 2,990'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Recent orders
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent orders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1),
                      },
                      children: [
                        const TableRow(
                          children: [
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Order ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Customer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                          ],
                        ),
                        if (orders.isNotEmpty)
                          ...orders.take(4).map((o) => TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('ORDR-${o.id.length > 5 ? o.id.substring(0, 5) : o.id}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(o.buyerName, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('PKR ${o.productPrice.toInt()} >', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                            ],
                          ))
                        else ...const [
                          TableRow(
                            children: [
                              Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('ORDR-45123', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Aisha Khan', style: TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('PKR 5,499 >', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                            ],
                          ),
                          TableRow(
                            children: [
                              Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('ORDR-45129', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Aisha Khan', style: TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('PKR 4,200 >', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardRightCol(List<AppOrder> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order-status Donut Chart Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order-status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(
                    painter: _DonutChartPainter(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _LegendItem('Packed', Color(0xFF0D9488)),
                  _LegendItem('Shipped', Color(0xFF2563EB)),
                  _LegendItem('Delivered', Color(0xFF059669)),
                  _LegendItem('Pending', Color(0xFFF59E0B)),
                  _LegendItem('Returned', Color(0xFFEF4444)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Low-stock alerts Card
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Low-stock alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('3', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2410C))),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('3 Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Items creating low stock warnings across best selling products.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Seller performance score Card
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
              const Text('Seller performance score', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              const Text('92%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.92,
                  minHeight: 6,
                  color: Color(0xFF059669),
                  backgroundColor: Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;

    final myOrders = state.orders.where((o) => o.sellerId == store.id).toList();
    final myProducts = state.products.where((p) => p.sellerId == store.id).toList();

    final pendingOrders = myOrders.where((o) => o.orderStatus == 'Pending').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title & Profile Completion
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        store.shopName.isNotEmpty ? store.shopName : 'Welcome store',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: Color(0xFF059669)),
                            SizedBox(width: 6),
                            Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Pakistani multi-vendor e-commerce marketplace', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),

              // Profile Completion Indicator
              Container(
                constraints: const BoxConstraints(maxWidth: 260),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Profile completion',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text('85%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 0.85,
                        minHeight: 6,
                        color: Color(0xFF059669),
                        backgroundColor: Color(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Main Top KPI Row & Quick Actions Panel
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 6 KPI Metric Cards Grid
              Expanded(
                flex: 3,
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.8,
                  children: [
                    _buildOverviewCard('Total sales', 'PKR 450,780', Icons.attach_money, const Color(0xFF2563EB)),
                    _buildOverviewCard('New orders', '${myOrders.isNotEmpty ? myOrders.length : 12}', Icons.info_outline, const Color(0xFF2563EB)),
                    _buildOverviewCard('Pending orders', '$pendingOrders', Icons.hourglass_empty_rounded, const Color(0xFFD97706)),
                    _buildOverviewCard('Store visitors', '3,210', Icons.people_alt_outlined, const Color(0xFF059669)),
                    _buildOverviewCard('Conversion rate', '2.8%', Icons.trending_up, const Color(0xFF2563EB)),
                    _buildOverviewCard('Available balance', 'PKR 125,500', Icons.account_balance_wallet_outlined, const Color(0xFF059669)),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Quick Actions Box
              Container(
                width: 240,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick actions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => onSelectSection('products_add'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => onSelectSection('marketing_vouchers'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Create Discount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => onSelectSection('orders_manage'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Print Shipping Labels', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => onSelectSection('finance_wallet'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Withdraw Funds', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (isWeb)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _buildDashboardLeftCol(myOrders, myProducts)),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: _buildDashboardRightCol(myOrders)),
              ],
            )
          else
            Column(
              children: [
                _buildDashboardLeftCol(myOrders, myProducts),
                const SizedBox(height: 24),
                _buildDashboardRightCol(myOrders),
              ],
            ),
        ],
      ),
    );
  }
}
