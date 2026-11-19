import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class LegalDocModel {
  final String id;
  final String title;
  final String slug;
  String version;
  String lastUpdated;
  String content;

  LegalDocModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.version,
    required this.lastUpdated,
    required this.content,
  });
}

class FaqItem {
  final String id;
  String question;
  String answer;
  String category; // 'Customer', 'Seller', 'Payments', 'Logistics'

  FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });
}

class ContactChannelModel {
  final String id;
  final String channelName;
  String value;
  final IconData icon;
  final Color iconColor;
  final String helperText;

  ContactChannelModel({
    required this.id,
    required this.channelName,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.helperText,
  });
}

class CmsContentScreen extends StatefulWidget {
  const CmsContentScreen({super.key});

  @override
  State<CmsContentScreen> createState() => _CmsContentScreenState();
}

class _CmsContentScreenState extends State<CmsContentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDocIndex = 0;
  String _faqFilterCategory = 'All';
  final TextEditingController _activeDocEditor = TextEditingController();

  final List<LegalDocModel> _legalDocs = [
    LegalDocModel(
      id: 'DOC-01',
      title: 'Terms of Service (Buyer & Marketplace)',
      slug: 'terms-of-service',
      version: 'v2.4',
      lastUpdated: '2026-08-15',
      content: '''1. Acceptance of Terms: By accessing or purchasing from Elegant Marketplace, you agree to comply with all applicable Pakistani trade and e-commerce laws.
2. User Accounts: Customers must provide accurate shipping addresses and verified mobile numbers for OTP authentication.
3. Order Acceptance & Pricing: Elegant Marketplace reserves the right to cancel orders with obvious pricing typographical errors before dispatch.
4. Prohibited Activities: Fraudulent chargebacks, abusive seller ratings, or harassment of delivery riders will result in permanent CNIC/phone blacklisting.''',
    ),
    LegalDocModel(
      id: 'DOC-02',
      title: 'Privacy & Personal Data Protection',
      slug: 'privacy-policy',
      version: 'v2.1',
      lastUpdated: '2026-08-10',
      content: '''1. Data Collection: We collect recipient names, phone numbers, GPS delivery coordinates, and email addresses solely for dispatching marketplace orders.
2. Payment Security: Elegant Marketplace never stores credit card CVVs or bank passwords. All transactions are securely tokenized via 1LINK, PayFast, and Meezan Bank 3D-Secure gateways.
3. Third-Party Sharing: Shipping details are shared strictly with contracted 3PL couriers (TCS, Leopards, CallCourier) to fulfill delivery.''',
    ),
    LegalDocModel(
      id: 'DOC-03',
      title: 'Seller Merchant Agreement & Code of Conduct',
      slug: 'seller-agreement',
      version: 'v1.9',
      lastUpdated: '2026-08-01',
      content: '''1. Authentic Products Guarantee: Selling counterfeit, replicated, or expired goods is strictly prohibited and subject to immediate PKR 50,000 penalty and merchant ban.
2. Dispatch SLA: Sellers must hand over packed parcels to courier riders within 24 hours of order placement.
3. Payout Cycles: Net marketplace payouts are automatically disbursed every Monday for all successfully delivered orders with cleared 7-day return periods.''',
    ),
    LegalDocModel(
      id: 'DOC-04',
      title: '7-Day Return & Refund Policy',
      slug: 'return-policy',
      version: 'v2.0',
      lastUpdated: '2026-07-28',
      content: '''1. Eligibility: Customers can claim returns within 7 calendar days of delivery for damaged, defective, or incorrect items.
2. Inspection & Payout: Upon courier return pickup and warehouse verification, refunds are credited to the customer Apna Wallet within 2 hours or reversed to original bank card within 3-5 business days.''',
    ),
  ];

  final List<FaqItem> _faqs = [
    FaqItem(
      id: 'FAQ-01',
      question: 'How do I track my order live?',
      answer: 'Go to "Account > My Orders" and click "Track Order" to see live GPS tracking and rider phone number.',
      category: 'Customer',
    ),
    FaqItem(
      id: 'FAQ-02',
      question: 'What is the return & replacement procedure?',
      answer: 'Open the delivered order in your app, click "Request Return", choose your reason, and a courier rider will pick it up within 48 hours for free.',
      category: 'Customer',
    ),
    FaqItem(
      id: 'FAQ-03',
      question: 'When do sellers receive weekly payout disbursements?',
      answer: 'Merchant earnings are processed every Monday directly into your verified IBAN account without manual withdrawal requests.',
      category: 'Seller',
    ),
    FaqItem(
      id: 'FAQ-04',
      question: 'How does Elegant Marketplace calculate commission fees?',
      answer: 'Category-level commission (between 3.5% to 12%) is automatically deducted from order subtotal before merchant disbursals.',
      category: 'Seller',
    ),
    FaqItem(
      id: 'FAQ-05',
      question: 'Which payment methods are supported in Pakistan?',
      answer: 'We support Cash on Delivery (COD), JazzCash, EasyPaisa, Meezan Bank Direct, and all Visa/Mastercard Debit/Credit Cards.',
      category: 'Payments',
    ),
  ];

  final List<ContactChannelModel> _contacts = [
    ContactChannelModel(
      id: 'CONT-01',
      channelName: 'Official Support Email',
      value: 'support@apnastore.pk',
      icon: Icons.email_outlined,
      iconColor: const Color(0xFF2563EB),
      helperText: 'Primary customer & seller ticketing inbox (24/7 monitoring)',
    ),
    ContactChannelModel(
      id: 'CONT-02',
      channelName: 'UAN Helpline Phone',
      value: '+92 (042) 111-276-278',
      icon: Icons.phone_in_talk_outlined,
      iconColor: const Color(0xFF059669),
      helperText: 'Toll-free customer service (Mon - Sat: 9:00 AM to 9:00 PM)',
    ),
    ContactChannelModel(
      id: 'CONT-03',
      channelName: 'Official WhatsApp Business Hotline',
      value: '+92 300 1234567',
      icon: Icons.chat_bubble_outline_rounded,
      iconColor: const Color(0xFF10B981),
      helperText: 'Instant buyer support chatbot & live human agent routing',
    ),
    ContactChannelModel(
      id: 'CONT-04',
      channelName: 'Headquarters Physical Office Address',
      value: 'Suite 402, Software Technology Park, Main Gulberg III, Lahore, Pakistan.',
      icon: Icons.location_on_outlined,
      iconColor: const Color(0xFFD97706),
      helperText: 'Official registered business address for legal notices & seller walk-ins',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _activeDocEditor.text = _legalDocs[0].content;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activeDocEditor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Breadcrumb & Header
          const Text('Breadcrumbs > Content > Platform CMS Editor', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CMS & Platform Content Editor', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Manage buyer/seller legal agreements, customer FAQ knowledge base, and official support helplines.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    onPressed: () {
                      adminState.logAuditAction('CMS_EXPORT', 'All Documents', 'Exported CMS content bundle.');
                      SuperAdminDialogs.showToast(context, 'Legal & FAQ content exported to JSON successfully!');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('Export Content Bundle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_done_rounded, size: 16),
                    onPressed: () {
                      adminState.logAuditAction('CMS_PUBLISH_LIVE', 'Global Marketplace', 'Published latest legal policies & CMS to customer mobile app.');
                      SuperAdminDialogs.showToast(context, 'All CMS changes published live to Mobile App & Web Storefront!');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('Publish Live to App', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Top Content KPI Cards (Clickable Quick Jump)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(0),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Published Legal Documents',
                    value: '${_legalDocs.length} Active Policies',
                    subtitle: 'Terms, Privacy, Seller, Returns (Tab 1)',
                    icon: Icons.gavel_rounded,
                    iconColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(1),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Knowledge Base FAQs',
                    value: '${_faqs.length} Live Articles',
                    subtitle: 'Buyer & Seller Answers (Tab 2)',
                    icon: Icons.quiz_outlined,
                    iconColor: const Color(0xFF10B981),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(2),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Active Support Channels',
                    value: '${_contacts.length} Live Channels',
                    subtitle: 'Email, UAN, WhatsApp, Office (Tab 3)',
                    icon: Icons.support_agent_rounded,
                    iconColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(0),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Latest Policy Revision',
                    value: 'August 2026',
                    subtitle: 'Live Version: v2.4 Standard',
                    icon: Icons.verified_user_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF3E8FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-Tabs Navigation
          Container(
            height: 48,
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
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.gavel_outlined, size: 18), text: 'Legal Policies & User Agreements'),
                Tab(icon: Icon(Icons.quiz_outlined, size: 18), text: 'FAQ Knowledge Base Management'),
                Tab(icon: Icon(Icons.contact_support_outlined, size: 18), text: 'Helpline & Official Contact Channels'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          SizedBox(
            height: 590,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLegalTab(adminState),
                _buildFaqTab(adminState),
                _buildContactSetupTab(adminState),
              ],
            ),
          ),
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
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: LEGAL POLICIES & USER AGREEMENTS (ENTERPRISE WORKSPACE)
  // ==========================================
  Widget _buildLegalTab(SuperAdminProvider adminState) {
    final currentDoc = _legalDocs[_selectedDocIndex];

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Document Directory (Flex 4)
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Platform Legal Documents', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const Text('Select policy to edit clauses & publish revisions.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _legalDocs.length,
                      itemBuilder: (context, index) {
                        final doc = _legalDocs[index];
                        final isSelected = index == _selectedDocIndex;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedDocIndex = index;
                                _activeDocEditor.text = doc.content;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.description_outlined, size: 20, color: isSelected ? Colors.white : const Color(0xFF2563EB)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(doc.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF0F172A))),
                                        const SizedBox(height: 2),
                                        Text('Version ${doc.version} • Updated ${doc.lastUpdated}', style: TextStyle(fontSize: 10, color: isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Right Rich Editor Workspace (Flex 7)
            Expanded(
              flex: 7,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentDoc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                            Text('Route: /legal/${currentDoc.slug} • Revision: ${currentDoc.version}', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save_rounded, size: 14),
                          label: const Text('Save & Publish Policy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                          onPressed: () {
                            setState(() {
                              currentDoc.content = _activeDocEditor.text;
                              currentDoc.lastUpdated = DateTime.now().toString().substring(0, 10);
                            });
                            adminState.logAuditAction('CMS_DOC_SAVE', currentDoc.title, 'Updated policy clauses.');
                            SuperAdminDialogs.showToast(context, '${currentDoc.title} saved and published!');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Quick Markdown Toolbar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Text('Quick Formatting: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: () {
                              _activeDocEditor.text += '\n### New Section Heading\n';
                            },
                            child: const Text('+ Heading', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () {
                              _activeDocEditor.text += '\n• Bullet point clause...\n';
                            },
                            child: const Text('+ Bullet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () {
                              _activeDocEditor.text += '\n> Important Legal Disclaimer: ';
                            },
                            child: const Text('+ Note', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          Text('${_activeDocEditor.text.length} characters', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Editor Textarea
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _activeDocEditor,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, height: 1.5, fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Type legal clauses, buyer terms, and merchant SLA...',
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
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

  // ==========================================
  // TAB 2: FAQ KNOWLEDGE BASE MANAGEMENT (2-COLUMN GRID)
  // ==========================================
  Widget _buildFaqTab(SuperAdminProvider adminState) {
    final filteredFaqs = _faqFilterCategory == 'All' ? _faqs : _faqs.where((f) => f.category == _faqFilterCategory).toList();

    final categories = ['All', 'Customer', 'Seller', 'Payments'];

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FAQ Knowledge Base Articles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Frequently asked questions displayed on Mobile App Help Center and Checkout screens.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ Add FAQ Article', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () => _showAddFaqModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category Filter Pills
            Row(
              children: categories.map((cat) {
                final isSelected = _faqFilterCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () => setState(() => _faqFilterCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // 2-Column Responsive FAQ Grid Layout
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 150,
                ),
                itemCount: filteredFaqs.length,
                itemBuilder: (context, index) {
                  final item = filteredFaqs[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                              child: Text(item.category, style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                  onPressed: () => _showEditFaqModal(item, adminState),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                                  onPressed: () {
                                    setState(() => _faqs.removeWhere((f) => f.id == item.id));
                                    adminState.logAuditAction('CMS_FAQ_DELETE', item.question, 'Deleted FAQ article.');
                                    SuperAdminDialogs.showToast(context, 'FAQ deleted.');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Q: ${item.question}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text('A: ${item.answer}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: HELPLINE CONTACT SETUP (2x2 GRID CARDS)
  // ==========================================
  Widget _buildContactSetupTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Official Platform Helpline & Support Contact Channels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('Public contact information shown in footer, support tickets, order confirmation emails, and app settings.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            // 2x2 Responsive Grid of Contact Channels
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 180,
                ),
                itemCount: _contacts.length,
                itemBuilder: (context, index) {
                  final contact = _contacts[index];

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: contact.iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                              child: Icon(contact.icon, color: contact.iconColor, size: 22),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                              child: const Text('ACTIVE 🟢', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(contact.channelName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(contact.value, style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Text(contact.helperText, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 12),
                            label: const Text('Edit Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () => _showEditContactModal(contact, adminState),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MODALS WITH CLEAN LIGHT THEME (NO CONTRAST BUGS)
  // ==========================================
  void _showAddFaqModal(SuperAdminProvider adminState) {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    String category = 'Customer';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.quiz_outlined, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 8),
                Text('Add FAQ Knowledge Article', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Target Category', border: OutlineInputBorder()),
                  items: ['Customer', 'Seller', 'Payments', 'Logistics'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setModalState(() => category = val ?? 'Customer'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(labelText: 'Question Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Detailed Answer Explanation', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                onPressed: () {
                  if (qCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) {
                    setState(() {
                      _faqs.add(FaqItem(
                        id: 'FAQ-0${_faqs.length + 1}',
                        question: qCtrl.text.trim(),
                        answer: aCtrl.text.trim(),
                        category: category,
                      ));
                    });
                    adminState.logAuditAction('CMS_FAQ_ADD', qCtrl.text, 'Added new FAQ article.');
                    Navigator.pop(ctx);
                    SuperAdminDialogs.showToast(context, 'FAQ Article Published Successfully!');
                  }
                },
                child: const Text('Publish FAQ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditFaqModal(FaqItem item, SuperAdminProvider adminState) {
    final qCtrl = TextEditingController(text: item.question);
    final aCtrl = TextEditingController(text: item.answer);
    String category = item.category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 8),
                Text('Edit FAQ Article', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Target Category', border: OutlineInputBorder()),
                  items: ['Customer', 'Seller', 'Payments', 'Logistics'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setModalState(() => category = val ?? 'Customer'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(labelText: 'Question Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Detailed Answer Explanation', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                onPressed: () {
                  if (qCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) {
                    setState(() {
                      item.question = qCtrl.text.trim();
                      item.answer = aCtrl.text.trim();
                      item.category = category;
                    });
                    adminState.logAuditAction('CMS_FAQ_EDIT', item.question, 'Updated FAQ article.');
                    Navigator.pop(ctx);
                    SuperAdminDialogs.showToast(context, 'FAQ Article Updated Successfully!');
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditContactModal(ContactChannelModel contact, SuperAdminProvider adminState) {
    final valCtrl = TextEditingController(text: contact.value);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit ${contact.channelName}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valCtrl,
              maxLines: contact.channelName.contains('Address') ? 3 : 1,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              decoration: InputDecoration(labelText: contact.channelName, border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              if (valCtrl.text.trim().isNotEmpty) {
                setState(() => contact.value = valCtrl.text.trim());
                adminState.logAuditAction('CMS_CONTACT_UPDATE', contact.channelName, 'Updated public support channel.');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, '${contact.channelName} updated successfully!');
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

