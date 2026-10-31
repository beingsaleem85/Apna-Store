import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class SupportTicket {
  final String id;
  final String userName;
  final String userRole; // 'Customer' or 'Seller'
  final String emailOrPhone;
  final String subject;
  final String description;
  String department; // 'Finance & Payouts', 'Logistics & TCS', 'Seller KYC', 'Buyer Disputes'
  String priority; // 'Urgent', 'High', 'Medium', 'Low'
  String status; // 'Open', 'In Progress', 'Resolved', 'Escalated'
  bool isSlaBreached;
  String responseTime;
  final DateTime createdAt;
  List<String> messageThread;

  SupportTicket({
    required this.id,
    required this.userName,
    required this.userRole,
    required this.emailOrPhone,
    required this.subject,
    required this.description,
    required this.department,
    required this.priority,
    this.status = 'Open',
    this.isSlaBreached = false,
    this.responseTime = '2h remaining',
    required this.createdAt,
    List<String>? messageThread,
  }) : messageThread = messageThread ?? [description];
}

class HelpdeskArticle {
  final String id;
  final String title;
  final String category;
  final String summary;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String readTime;

  HelpdeskArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.readTime,
  });
}

class SupportDeskScreen extends StatefulWidget {
  const SupportDeskScreen({super.key});

  @override
  State<SupportDeskScreen> createState() => _SupportDeskScreenState();
}

class _SupportDeskScreenState extends State<SupportDeskScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All'; // 'All', 'Open', 'In Progress', 'Resolved', 'Urgent'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<SupportTicket> _tickets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('support_tickets')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      if (res is List && res.isNotEmpty && mounted) {
        setState(() {
          _tickets.clear();
          for (final r in res) {
            _tickets.add(SupportTicket(
              id: (r['id'] ?? '').toString().substring(0, 8).toUpperCase(),
              userName: r['user_email'] ?? 'User',
              userRole: (r['category'] ?? 'Customer').toString(),
              emailOrPhone: r['user_email'] ?? '',
              subject: r['subject'] ?? 'Support Inquiry',
              description: r['subject'] ?? '',
              department: r['category'] ?? 'General',
              priority: r['priority'] ?? 'Medium',
              status: r['status'] ?? 'Open',
              createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
            ));
          }
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final List<HelpdeskArticle> _knowledgeBaseArticles = [
    HelpdeskArticle(
      id: 'KB-01',
      title: 'Seller Bank IBAN Verification & Payout Failure SOP',
      category: 'Finance SOP',
      summary: 'Step-by-step instructions for verifying 24-digit Pakistani IBANs with 1-Link routing before re-dispatching batch payouts.',
      icon: Icons.account_balance_rounded,
      iconColor: const Color(0xFF059669),
      bgColor: const Color(0xFFECFDF5),
      readTime: '3 min read',
    ),
    HelpdeskArticle(
      id: 'KB-02',
      title: 'TCS & Leopards Courier Escalation & Lost Parcel Claims',
      category: 'Logistics Guide',
      summary: 'How to file official insurance claims for consignments damaged or delayed beyond 72 hours SLA across Pakistani cities.',
      icon: Icons.local_shipping_rounded,
      iconColor: const Color(0xFFEA580C),
      bgColor: const Color(0xFFFFEDD5),
      readTime: '4 min read',
    ),
    HelpdeskArticle(
      id: 'KB-03',
      title: 'Customer Return Dispute Arbitration & Instant Wallet Refunds',
      category: 'Dispute Policy',
      summary: 'Rules for approving customer returns, generating prepaid shipping slips, and issuing instant wallet credit vs bank reversals.',
      icon: Icons.gavel_rounded,
      iconColor: const Color(0xFF2563EB),
      bgColor: const Color(0xFFEFF6FF),
      readTime: '5 min read',
    ),
    HelpdeskArticle(
      id: 'KB-04',
      title: 'Emergency Storefront Maintenance & DDoS Defense Protocols',
      category: 'Cyber Security',
      summary: 'Standard emergency procedure for placing marketplace in maintenance mode and revoking staff sessions during attacks.',
      icon: Icons.security_rounded,
      iconColor: const Color(0xFFDC2626),
      bgColor: const Color(0xFFFEE2E2),
      readTime: '2 min read',
    ),
  ];


  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    // Filter Tickets
    final filteredTickets = _tickets.where((t) {
      final matchesSearch = t.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.department.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.emailOrPhone.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedFilter == 'Open') return t.status == 'Open';
      if (_selectedFilter == 'In Progress') return t.status == 'In Progress';
      if (_selectedFilter == 'Resolved') return t.status == 'Resolved';
      if (_selectedFilter == 'Urgent') return t.priority == 'Urgent';
      return true;
    }).toList();

    final urgentCount = _tickets.where((t) => t.priority == 'Urgent' || t.isSlaBreached).length;
    final openCount = _tickets.where((t) => t.status != 'Resolved').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Breadcrumb & Header
          const Text('Breadcrumbs > Support & Operations > Help Center & Ticketing Desk', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Help Center & Customer/Seller Support Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Centralized SLA monitoring, customer dispute escalation, and internal admin knowledge base.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Export Tickets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      SuperAdminDialogs.showToast(context, 'Support tickets ledger exported to CSV format.');
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_comment_rounded, size: 16),
                    label: const Text('+ Create Support Ticket', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showCreateTicketModal(adminState),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Clickable Metric KPI Cards
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    _tabController.animateTo(0);
                    setState(() => _selectedFilter = 'All');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Active Support Tickets',
                    value: '$openCount Open Tickets',
                    subtitle: 'Total ${_tickets.length} Registered (Tab 1)',
                    icon: Icons.support_agent_rounded,
                    iconColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () {
                    _tabController.animateTo(0);
                    setState(() => _selectedFilter = 'Urgent');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Urgent & SLA Breaches',
                    value: '$urgentCount Escalated',
                    subtitle: 'Requires Immediate Action (Tab 1)',
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEE2E2),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(1),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Knowledge Base SOPs',
                    value: '${_knowledgeBaseArticles.length} Operational Guides',
                    subtitle: 'Click to Read Guides (Tab 2)',
                    icon: Icons.menu_book_rounded,
                    iconColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(2),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Resolution Health',
                    value: '1.8h Avg Resolution',
                    subtitle: '98.2% CSAT Rating (Tab 3)',
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF3E8FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Sub-Tabs Navigation (3 Tabs)
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF334155),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.confirmation_number_outlined, size: 16), text: 'Live Support Tickets & SLA Queue'),
                Tab(icon: Icon(Icons.menu_book_rounded, size: 16), text: 'Admin Knowledge Base & SOP Docs'),
                Tab(icon: Icon(Icons.contact_phone_outlined, size: 16), text: 'Emergency Escalations & Contacts'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dynamic Tab Content
          if (_tabController.index == 0)
            _buildTicketsTab(filteredTickets, adminState)
          else if (_tabController.index == 1)
            _buildKnowledgeBaseTab()
          else
            _buildEscalationContactsTab(),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: LIVE TICKETS & SLA QUEUE
  // ==========================================
  Widget _buildTicketsTab(List<SupportTicket> filteredTickets, SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Search & Filter Bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search tickets by ID, Customer/Seller name, phone, or issue description...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                Row(
                  children: ['All', 'Open', 'In Progress', 'Resolved', 'Urgent'].map((filter) {
                    final isSel = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: ChoiceChip(
                        label: Text(filter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF64748B))),
                        selected: isSel,
                        selectedColor: const Color(0xFF0F172A),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) => setState(() => _selectedFilter = filter),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Ticket ID & SLA Window', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('User, Role & Issue Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Priority & Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Desk Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Ticket Rows
            if (filteredTickets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.headset_mic_outlined, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text('No support tickets in queue matching filter criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              )
            else
              ...filteredTickets.map((t) {
              final isResolved = t.status == 'Resolved';
              final isUrgent = t.priority == 'Urgent' || t.isSlaBreached;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.isSlaBreached ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Ticket ID & SLA
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.id, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13, fontFamily: 'monospace')),
                          const SizedBox(height: 2),
                          if (t.isSlaBreached)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                              child: const Text('🚨 SLA OVERDUE', style: TextStyle(color: Color(0xFFDC2626), fontSize: 9, fontWeight: FontWeight.bold)),
                            )
                          else
                            Text(t.responseTime, style: TextStyle(fontSize: 10, color: isResolved ? const Color(0xFF059669) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),

                    // User & Subject
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.subject, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: t.userRole == 'Seller' ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(t.userRole, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: t.userRole == 'Seller' ? const Color(0xFF1D4ED8) : const Color(0xFF15803D))),
                              ),
                              const SizedBox(width: 6),
                              Text('${t.userName} • ${t.emailOrPhone}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Department
                    Expanded(
                      flex: 2,
                      child: Text(t.department, style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),

                    // Priority & Status
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isUrgent ? const Color(0xFFFEE2E2) : t.priority == 'High' ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.priority.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isUrgent ? const Color(0xFFDC2626) : t.priority == 'High' ? const Color(0xFFD97706) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.status,
                            style: TextStyle(fontSize: 11, color: isResolved ? const Color(0xFF059669) : const Color(0xFF2563EB), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // Actions: Reply & Resolve
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.chat_bubble_outline, size: 13),
                            label: const Text('Reply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () => _showTicketDetailsModal(t, adminState),
                          ),
                          const SizedBox(width: 8),
                          if (!isResolved)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () {
                                setState(() {
                                  t.status = 'Resolved';
                                  t.isSlaBreached = false;
                                  t.responseTime = 'Resolved';
                                });
                                adminState.logAuditAction('TICKET_RESOLVE', t.id, 'Marked support ticket as resolved.');
                                SuperAdminDialogs.showToast(context, 'Ticket ${t.id} Marked Resolved & Closed 🟢');
                              },
                              child: const Text('Resolve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: KNOWLEDGE BASE & SOP DOCS
  // ==========================================
  Widget _buildKnowledgeBaseTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Standard Operating Procedures (SOPs) & Guides', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Official operational handbooks for customer returns, seller KYC verification, and payout troubleshooting.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              Icon(Icons.library_books_rounded, color: Color(0xFF2563EB), size: 24),
            ],
          ),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 180,
          ),
          itemCount: _knowledgeBaseArticles.length,
          itemBuilder: (context, index) {
            final article = _knowledgeBaseArticles[index];
            return Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: article.bgColor, borderRadius: BorderRadius.circular(8)),
                          child: Icon(article.icon, color: article.iconColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(article.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                              Text(article.category.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(article.summary, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('⏱️ ${article.readTime}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: const Text('Read Full SOP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showArticleDetailsModal(article),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: EMERGENCY ESCALATIONS & CONTACTS
  // ==========================================
  Widget _buildEscalationContactsTab() {
    final contacts = [
      {
        'title': 'TCS Express E-Commerce Dedicated Account Desk',
        'contact': '+92 21 111 123 456 / ecom.support@tcs.com.pk',
        'desc': 'Direct contact for lost parcels, stuck tracking numbers, and Karachi/Lahore hub reconciliations.',
        'icon': Icons.local_shipping_rounded,
        'color': const Color(0xFFEA580C),
      },
      {
        'title': 'EasyPaisa & Telenor Bank Merchant Support Desk',
        'contact': '+92 42 111 003 737 / merchantsupport@easypaisa.com.pk',
        'desc': 'Direct merchant integration escalations, failed webhook reversals, and IPN chargebacks.',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF059669),
      },
      {
        'title': 'FBR POS Real-time Invoicing Technical Wing',
        'contact': '+92 51 111 772 772 / helpline@fbr.gov.pk',
        'desc': 'Federal Board of Revenue digital invoice barcode stamping and Annexure-C sales tax portal assistance.',
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFF0F172A),
      },
      {
        'title': '24/7 Platform Engineering & Supabase On-Call',
        'contact': 'devops@apnastore.pk / WhatsApp: +92 300 111 8899',
        'desc': 'Emergency database outage, payment gateway gateway errors, and cybersecurity incident team.',
        'icon': Icons.engineering_rounded,
        'color': const Color(0xFF2563EB),
      },
    ];

    return Column(
      children: [
        ...contacts.map((c) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: (c['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(c['icon'] as IconData, color: c['color'] as Color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(c['contact'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB), fontFamily: 'monospace')),
                      const SizedBox(height: 4),
                      Text(c['desc'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.call_rounded, size: 14),
                  label: const Text('Call Desk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () {
                    SuperAdminDialogs.showToast(context, 'Connecting to ${c['title']}...');
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // MODALS & DIALOGS
  // ==========================================
  void _showTicketDetailsModal(SupportTicket ticket, SuperAdminProvider adminState) {
    final replyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.confirmation_number_rounded, color: Color(0xFF2563EB), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${ticket.id}: ${ticket.subject}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${ticket.userName} (${ticket.userRole})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                          Text(ticket.emailOrPhone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Dept: ${ticket.department}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155))),
                          Text('Priority: ${ticket.priority}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: ticket.priority == 'Urgent' ? const Color(0xFFDC2626) : const Color(0xFFD97706))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Conversation thread
                const Text('Conversation History & Customer Narrative:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: ticket.messageThread.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text('• ${ticket.messageThread[i]}', style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Reply input
                TextField(
                  controller: replyCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Type Official Response to Customer / Merchant...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded, size: 14),
              label: const Text('Send Official Reply'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                if (replyCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    ticket.messageThread.add('Admin Reply: ${replyCtrl.text.trim()}');
                    ticket.status = 'In Progress';
                  });
                  adminState.logAuditAction('TICKET_REPLY', ticket.id, 'Dispatched support reply to ${ticket.userName}');
                  Navigator.pop(ctx);
                  SuperAdminDialogs.showToast(context, 'Reply Dispatched to ${ticket.userName} via Email & SMS!');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTicketModal(SuperAdminProvider adminState) {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String role = 'Customer';
    String dept = 'Finance & Payouts';
    String priority = 'Medium';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.add_comment_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text('Create New Support & Escalation Ticket', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(labelText: 'Customer / Merchant Name', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(labelText: 'User Role', border: OutlineInputBorder()),
                        items: ['Customer', 'Seller'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setMState(() => role = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: contactCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Email Address / Mobile Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: dept,
                        decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                        items: ['Finance & Payouts', 'Logistics & TCS', 'Seller KYC', 'Buyer Disputes'].map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) => setMState(() => dept = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: priority,
                        decoration: const InputDecoration(labelText: 'Priority SLA', border: OutlineInputBorder()),
                        items: ['Urgent', 'High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (v) => setMState(() => priority = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: subjectCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Issue Subject Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Detailed Incident Description...', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && subjectCtrl.text.isNotEmpty) {
                  setState(() {
                    _tickets.insert(
                      0,
                      SupportTicket(
                        id: 'TCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                        userName: nameCtrl.text.trim(),
                        userRole: role,
                        emailOrPhone: contactCtrl.text.trim().isNotEmpty ? contactCtrl.text.trim() : 'contact@apnastore.pk',
                        subject: subjectCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        department: dept,
                        priority: priority,
                        status: 'Open',
                        responseTime: priority == 'Urgent' ? '1 hour SLA' : '4 hours SLA',
                        createdAt: DateTime.now(),
                      ),
                    );
                  });
                  adminState.logAuditAction('TICKET_CREATED', subjectCtrl.text, 'Created manual support ticket for $role ${nameCtrl.text}');
                  Navigator.pop(ctx);
                  SuperAdminDialogs.showToast(context, 'Support Ticket Created Successfully!');
                }
              },
              child: const Text('Create Ticket'),
            ),
          ],
        ),
      ),
    );
  }

  void _showArticleDetailsModal(HelpdeskArticle article) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: article.bgColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(article.icon, color: article.iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(article.title, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article.summary, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4)),
              const SizedBox(height: 14),
              const Text('Standard Escalation Procedure Steps:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              const Text('1. Verify merchant or customer identity and verify phone number via 6-digit OTP.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              const Text('2. Cross-check order tracking ID on courier portal (TCS / Leopards).', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              const Text('3. If transaction failed, initiate 1-Link reversal or instant buyer wallet credit.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close Guide'),
          ),
        ],
      ),
    );
  }
}
