import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_state_provider.dart';
import '../../../core/services/app_auth_provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/constants/theme.dart';
import '../../../core/widgets/dev_version_banner.dart';
import '../../../core/widgets/app_footer.dart';

class SellerLandingPage extends StatefulWidget {
  const SellerLandingPage({super.key});

  @override
  State<SellerLandingPage> createState() => _SellerLandingPageState();
}

class _SellerLandingPageState extends State<SellerLandingPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  final _heroLoginFormKey = GlobalKey<FormState>();

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _benefitsKey = GlobalKey();
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _successKey = GlobalKey();
  final GlobalKey _programsKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);

    if (state.isSellerLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/seller/dashboard');
        }
      });
      return const Scaffold(
        backgroundColor: Color(0xFF00382E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFDB913)),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isTablet = MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 900;

    return Column(
      children: [
        const DevVersionBanner(),
        Expanded(
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: _buildHeader(context, isDesktop),
            body: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // 1. Hero Section
                  _buildHeroSection(context, state, isDesktop, isTablet),

            // 2. Seller Benefits Section
            Container(key: _benefitsKey, child: _buildSellerBenefitsSection(isDesktop)),

            // 3. How to Start Selling Section
            Container(key: _howItWorksKey, child: _buildHowToStartSection(isDesktop)),

            // 4. Success Stories Section
            Container(key: _successKey, child: _buildSuccessStoriesSection(isDesktop)),

            // 5. Seller Programs Section
            Container(key: _programsKey, child: _buildSellerProgramsSection(isDesktop)),

            // 6. Seller Resources Section
            _buildSellerResourcesSection(isDesktop),

            // 7. Frequently Asked Questions Section
            Container(key: _faqKey, child: _buildFaqSection(isDesktop)),

            // 8. Final CTA Section
            _buildFinalCtaSection(context, isDesktop),

            // 9. Footer Section
            const AppFooter(),
          ],
        ),
      ),
    ),
  ),
],
);
  }

  // ==========================================
  // HEADER / NAVBAR
  // ==========================================
  PreferredSizeWidget _buildHeader(BuildContext context, bool isDesktop) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      titleSpacing: isDesktop ? 40 : 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Elegant',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  height: 1.1,
                ),
              ),
              Text(
                'SELLER CENTER',
                style: TextStyle(
                  color: AppTheme.secondaryGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (isDesktop) ...[
          TextButton(
            onPressed: () => _scrollToSection(_benefitsKey),
            child: const Text('Benefits', style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _scrollToSection(_howItWorksKey),
            child: const Text('How to Sell', style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _scrollToSection(_successKey),
            child: const Text('Success Stories', style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _scrollToSection(_programsKey),
            child: const Text('Programs', style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _scrollToSection(_faqKey),
            child: const Text('FAQs', style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 24),
        ],
        OutlinedButton(
          onPressed: () => Navigator.pushNamed(context, '/seller/login'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryGreen,
            side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Login', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/seller/register'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 0,
          ),
          child: const Text('Register Now', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        SizedBox(width: isDesktop ? 40 : 16),
      ],
    );
  }

  // ==========================================
  // 1. HERO SECTION
  // ==========================================
  Widget _buildHeroSection(BuildContext context, AppStateProvider state, bool isDesktop, bool isTablet) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00332C), Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: isDesktop ? 70 : 40,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: _buildHeroLeftText(context)),
                    const SizedBox(width: 60),
                    Expanded(flex: 5, child: _buildHeroLoginCard(context, state)),
                  ],
                )
              : Column(
                  children: [
                    _buildHeroLeftText(context),
                    const SizedBox(height: 40),
                    _buildHeroLoginCard(context, state),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroLeftText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.secondaryGold.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.secondaryGold.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, color: AppTheme.secondaryGold, size: 18),
              const SizedBox(width: 8),
              Text(
                'GROWTH POWERED BY ELEGANT MARKETPLACE',
                style: TextStyle(
                  color: AppTheme.secondaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Start Selling with\nElegant Marketplace',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Join thousands of successful entrepreneurs and business owners across Pakistan. Reach millions of active buyers with low transparent commissions, fast payouts, and dedicated seller support.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/seller/register'),
              icon: const Icon(Icons.rocket_launch, size: 20),
              label: const Text('Become a Seller', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _scrollToSection(_howItWorksKey),
              icon: const Icon(Icons.play_circle_outline, size: 20),
              label: const Text('Learn How It Works', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            _buildHeroStat('15,000+', 'Active Sellers'),
            Container(height: 30, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 24)),
            _buildHeroStat('150+', 'Cities Covered'),
            Container(height: 30, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 24)),
            _buildHeroStat('99.2%', 'On-Time Payouts'),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroStat(String title, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: AppTheme.secondaryGold, fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildHeroLoginCard(BuildContext context, AppStateProvider state) {
    return Card(
      elevation: 12,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _heroLoginFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_open_rounded, color: AppTheme.primaryGreen, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seller Login',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      ),
                      Text(
                        'Access your merchant dashboard',
                        style: TextStyle(fontSize: 12, color: AppTheme.lightText),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Email / Phone Field
              const Text('Email or Mobile Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'seller1@store.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.lightText),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter email or phone';
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Password Field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText)),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/seller/forgot-password'),
                    child: const Text('Forgot Password?', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.lightText),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppTheme.lightText,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter password';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: AppTheme.primaryGreen,
                      onChanged: (val) => setState(() => _rememberMe = val ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Remember Me', style: TextStyle(color: AppTheme.darkText, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () async {
                  if (_heroLoginFormKey.currentState!.validate()) {
                    try {
                      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
                      final role = await authProvider.login(_emailController.text, _passwordController.text);
                      if (!mounted) return;
                      final currentUser = authProvider.currentUser;
                      if (currentUser != null) {
                        final normalizedRole = (role ?? '').toLowerCase();
                        if (normalizedRole == 'seller' ||
                            normalizedRole == 'admin' ||
                            normalizedRole == 'superadmin' ||
                            normalizedRole == 'super_admin' ||
                            normalizedRole == 'owner') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logged in successfully!'), backgroundColor: Colors.green),
                          );
                          Navigator.pushReplacementNamed(context, '/seller/dashboard');
                        } else {
                          await authProvider.signOut();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('This account is not registered as a seller.'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid email address or password.'), backgroundColor: Colors.redAccent),
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid email address or password.'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                child: const Text('Login to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Don\'t have a store yet?', style: TextStyle(color: AppTheme.lightText, fontSize: 13)),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/seller/register'),
                    child: const Text('Register Now', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'By signing in, you agree to Elegant Marketplace Merchant Agreement and Privacy Policy.',
                style: TextStyle(fontSize: 11, color: AppTheme.lightText, height: 1.3),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. SELLER BENEFITS SECTION
  // ==========================================
  Widget _buildSellerBenefitsSection(bool isDesktop) {
    final benefits = [
      {'title': 'Low Commission', 'desc': 'Transparent flat commission rates starting from 8% to max 12%.', 'icon': Icons.savings_outlined},
      {'title': 'Fast Payments', 'desc': 'Automated weekly earnings payout directly into your bank account.', 'icon': Icons.payments_outlined},
      {'title': 'Nationwide Selling', 'desc': 'Deliver products seamlessly to buyers in 150+ cities in Pakistan.', 'icon': Icons.map_outlined},
      {'title': 'Secure Platform', 'desc': 'Advanced fraud prevention and verified buyer checkout protection.', 'icon': Icons.verified_user_outlined},
      {'title': 'Easy Product Listing', 'desc': 'Intuitive catalog upload tools supporting multi-variant options.', 'icon': Icons.inventory_2_outlined},
      {'title': 'Inventory Management', 'desc': 'Real-time stock level alerts, multi-warehouse sync, and low stock warnings.', 'icon': Icons.warehouse_outlined},
      {'title': 'Marketing Tools', 'desc': 'Run CPC sponsored ads, seasonal Flash Sales, and customer discount vouchers.', 'icon': Icons.campaign_outlined},
      {'title': 'Analytics Dashboard', 'desc': 'Real-time analytics on sales revenue, store visits, and conversion rates.', 'icon': Icons.bar_chart_outlined},
      {'title': 'Order Tracking', 'desc': 'Automated shipping labels, dispatch desks, and doorstep courier pickups.', 'icon': Icons.local_shipping_outlined},
      {'title': 'Customer Reviews', 'desc': 'Build brand trust with star ratings, buyer feedback, and verified badges.', 'icon': Icons.rate_review_outlined},
      {'title': '24/7 Seller Support', 'desc': 'Dedicated merchant help desk and priority account manager assistance.', 'icon': Icons.support_agent_outlined},
      {'title': 'Mobile Friendly', 'desc': 'Manage your entire shop smoothly from any desktop, laptop, or mobile phone.', 'icon': Icons.phone_android_outlined},
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 80,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSectionHeader('Why Sell on Elegant Marketplace?', 'Everything you need to grow your retail business online nationwide'),
              const SizedBox(height: 50),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: benefits.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 4 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final b = benefits[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: const Color(0xFFF8FAFC),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(b['icon'] as IconData, color: AppTheme.primaryGreen, size: 28),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            b['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkText),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            b['desc'] as String,
                            style: const TextStyle(fontSize: 12, color: AppTheme.lightText, height: 1.4),
                          ),
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

  // ==========================================
  // 3. HOW TO START SELLING SECTION
  // ==========================================
  Widget _buildHowToStartSection(bool isDesktop) {
    final steps = [
      {'step': '01', 'title': 'Create Seller Account', 'desc': 'Fill out your merchant details in less than 2 minutes.'},
      {'step': '02', 'title': 'Verify Identity', 'desc': 'Upload your CNIC and business NTN documents for instant review.'},
      {'step': '03', 'title': 'Setup Shop Profile', 'desc': 'Customize your shop logo, banner, return address, and policies.'},
      {'step': '04', 'title': 'List Your Products', 'desc': 'Add catalog items with photos, prices, descriptions, and variations.'},
      {'step': '05', 'title': 'Receive & Ship Orders', 'desc': 'Pack customer orders, print labels, and hand over to our courier partner.'},
      {'step': '06', 'title': 'Receive Fast Payouts', 'desc': 'Get weekly automatic payouts directly into your linked bank account.'},
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFF1F5F9),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 80,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSectionHeader('How to Start Selling in 6 Easy Steps', 'Launch your online shop today with zero technical hassle'),
              const SizedBox(height: 50),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: steps.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  final s = steps[index];
                  return Card(
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.04),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'STEP ${s['step']}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              Icon(Icons.arrow_forward, color: Colors.grey.shade300, size: 20),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            s['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.darkText),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s['desc'] as String,
                            style: const TextStyle(fontSize: 13, color: AppTheme.lightText, height: 1.4),
                          ),
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

  // ==========================================
  // 4. SUCCESS STORIES SECTION
  // ==========================================
  Widget _buildSuccessStoriesSection(bool isDesktop) {
    final stories = [
      {
        'name': 'Muhammad Ali',
        'store': 'Shahi Leather Art',
        'city': 'Lahore',
        'cat': 'Leather & Fashion',
        'sales': 'PKR 1,250,000 / mo',
        'rating': '5.0 ⭐',
        'story': 'Elegant Marketplace enabled us to take our traditional leather workshop in Lahore to customers across Pakistan. Weekly payouts and low fees keep our business thriving.',
        'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80'
      },
      {
        'name': 'Gulab Din',
        'store': 'Gulab Itr House',
        'city': 'Karachi',
        'cat': 'Traditional Perfumes',
        'sales': 'PKR 850,000 / mo',
        'rating': '4.9 ⭐',
        'story': 'We started with just 3 traditional attar scents. Today, Elegant Marketplace marketing tools and flash sales have helped us build a brand with thousands of repeat buyers.',
        'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&q=80'
      },
      {
        'name': 'Hamza Tech',
        'store': 'Mega Tech & Mart',
        'city': 'Islamabad',
        'cat': 'Electronics & Accessories',
        'sales': 'PKR 3,400,000 / mo',
        'rating': '4.9 ⭐',
        'story': 'The automated order tracking, bulk variations manager, and seller support made scaling our electronics inventory completely effortless.',
        'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&q=80'
      },
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 80,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSectionHeader('Seller Success Stories', 'Real merchants growing their revenue every single day on Elegant Marketplace'),
              const SizedBox(height: 50),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 3 : 1,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final st = stories[index];
                  return Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundImage: NetworkImage(st['image']!),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(st['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkText)),
                                    Text('${st['store']} • ${st['city']}', style: const TextStyle(fontSize: 12, color: AppTheme.lightText)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Monthly Sales', style: TextStyle(fontSize: 10, color: AppTheme.lightText, fontWeight: FontWeight.bold)),
                                    Text(st['sales']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(st['rating']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '"${st['story']}"',
                            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.darkText, height: 1.5),
                          ),
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

  // ==========================================
  // 5. SELLER PROGRAMS SECTION
  // ==========================================
  Widget _buildSellerProgramsSection(bool isDesktop) {
    final programs = [
      {
        'title': 'Verified Seller',
        'badge': 'TRUSTED BADGE',
        'icon': Icons.verified,
        'color': Colors.blue,
        'desc': 'Earn an official verified checkmark on your shop and products to build instant customer credibility.'
      },
      {
        'title': 'Premium Store',
        'badge': 'PREMIUM TIER',
        'icon': Icons.workspace_premium,
        'color': Colors.purple,
        'desc': 'Get priority homepage placements, dedicated account manager support, and reduced platform commission rates.'
      },
      {
        'title': 'Featured Seller',
        'badge': 'CAMPAIGN BOOST',
        'icon': Icons.star,
        'color': Colors.amber,
        'desc': 'Participate in Mega Sale events, Flash Sales, and Ramzan campaigns with high promotional visibility.'
      },
      {
        'title': 'Wholesale Seller',
        'badge': 'B2B BULK',
        'icon': Icons.all_inbox,
        'color': Colors.teal,
        'desc': 'Supply bulk volume orders to corporate B2B clients with tier-based volume pricing controls.'
      },
      {
        'title': 'International Seller',
        'badge': 'GLOBAL EXPORT',
        'icon': Icons.public,
        'color': Colors.indigo,
        'desc': 'Export authentic Pakistani products to overseas Pakistani buyers worldwide with full export clearance support.'
      },
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 80,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSectionHeader('Exclusive Seller Programs', 'Tailored marketplace growth programs designed for every stage of your business'),
              const SizedBox(height: 50),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: programs.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, index) {
                  final p = programs[index];
                  final color = p['color'] as Color;
                  return Card(
                    elevation: 3,
                    shadowColor: Colors.black.withOpacity(0.04),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(p['icon'] as IconData, color: color, size: 36),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  p['badge'] as String,
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            p['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.darkText),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            p['desc'] as String,
                            style: const TextStyle(fontSize: 13, color: AppTheme.lightText, height: 1.4),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/seller/register'),
                            icon: const Text('Learn More', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                            label: const Icon(Icons.arrow_forward_sharp, size: 14, color: AppTheme.primaryGreen),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          ),
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

  // ==========================================
  // 6. SELLER RESOURCES SECTION
  // ==========================================
  Widget _buildSellerResourcesSection(bool isDesktop) {
    final resources = [
      {'title': 'Seller Academy', 'desc': 'Comprehensive guides and seller university modules to master online retail.', 'icon': Icons.school_outlined},
      {'title': 'Video Tutorials', 'desc': 'Step-by-step video lessons on product photography, packaging, and ads.', 'icon': Icons.ondemand_video_outlined},
      {'title': 'Documentation', 'desc': 'Detailed marketplace rules, commission fee breakdown, and return policies.', 'icon': Icons.menu_book_outlined},
      {'title': 'FAQs', 'desc': 'Quick answers to common questions about onboarding, payouts, and shipping.', 'icon': Icons.help_outline},
      {'title': 'Community Forum', 'desc': 'Connect with 15,000+ active sellers, share growth tips, and network.', 'icon': Icons.forum_outlined},
      {'title': 'Support Center', 'desc': 'Dedicated 24/7 merchant help desk for fast issue resolution.', 'icon': Icons.headset_mic_outlined},
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 80,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSectionHeader('Seller Learning & Support Resources', 'Everything you need to boost your knowledge and operate smoothly'),
              const SizedBox(height: 50),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: resources.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (context, index) {
                  final r = resources[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: const Color(0xFFF8FAFC),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(r['icon'] as IconData, color: AppTheme.primaryGreen, size: 32),
                          const SizedBox(height: 16),
                          Text(
                            r['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkText),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            r['desc'] as String,
                            style: const TextStyle(fontSize: 12, color: AppTheme.lightText, height: 1.4),
                          ),
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

  // ==========================================
  // 7. FREQUENTLY ASKED QUESTIONS SECTION
  // ==========================================
  Widget _buildFaqSection(bool isDesktop) {
    final faqs = [
      {
        'q': 'How do I register as a seller on Elegant Marketplace?',
        'a': 'Click on "Register Now", complete the 3-step onboarding form (Personal Info, Shop Setup, and OTP verification), and submit your application. Your store will be reviewed within 24 hours.'
      },
      {
        'q': 'What are the commission fees for selling on Elegant Marketplace?',
        'a': 'Elegant Marketplace charges a transparent flat commission rate of 8% to 12% depending on the product category. There are no hidden listing fees or signup charges!'
      },
      {
        'q': 'When and how will I receive my seller payments?',
        'a': 'Earnings from delivered orders are automatically disbursed every week directly into your linked bank account or mobile wallet (JazzCash / Easypaisa).'
      },
      {
        'q': 'How does shipping and order delivery work?',
        'a': 'When a customer places an order, you pack the items, print the shipping label from your Seller Dashboard, and our logistics partner picks it up directly from your doorstep.'
      },
      {
        'q': 'How long does store and product listing approval take?',
        'a': 'Store registration and new product listings are reviewed by our moderation team within 24 hours to ensure high marketplace quality standards.'
      },
      {
        'q': 'What happens if a customer requests a return or refund?',
        'a': 'Returns are processed according to our Fair Marketplace Return Policy. If a return is valid, the item is returned back to your warehouse safely.'
      },
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 80,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              _buildSectionHeader('Frequently Asked Questions', 'Quick answers to common questions about selling on Elegant Marketplace'),
              const SizedBox(height: 50),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: faqs.length,
                itemBuilder: (context, index) {
                  final f = faqs[index];
                  return Card(
                    elevation: 1,
                    shadowColor: Colors.black.withOpacity(0.03),
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: ExpansionTile(
                      title: Text(
                        f['q']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.darkText),
                      ),
                      iconColor: AppTheme.primaryGreen,
                      childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                      children: [
                        Text(
                          f['a']!,
                          style: const TextStyle(fontSize: 13, color: AppTheme.lightText, height: 1.5),
                        ),
                      ],
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

  // ==========================================
  // 8. FINAL CTA SECTION
  // ==========================================
  Widget _buildFinalCtaSection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF002720)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 80,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGold.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.rocket_launch, color: AppTheme.secondaryGold, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ready to Start Selling on Elegant Marketplace?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              const Text(
                'Join over 15,000+ businesses across Pakistan and start reaching millions of online shoppers today.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              Wrap(
                spacing: 20,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/seller/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                    child: const Text('Register Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/seller/login'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Seller Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 9. FOOTER SECTION
  // ==========================================
  Widget _buildSellerFooter(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A), // Slate Dark Black
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 60,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isDesktop ? 4 : 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.storefront, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Elegant Marketplace Seller Center',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Pakistan\'s premier multi-vendor e-commerce marketplace empowering merchants, retailers, and artisans nationwide.',
                          style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildSocialIcon('https://img.icons8.com/color/48/facebook-new.png'),
                            const SizedBox(width: 10),
                            _buildSocialIcon('https://img.icons8.com/color/48/instagram-new.png'),
                            const SizedBox(width: 10),
                            _buildSocialIcon('https://img.icons8.com/color/48/youtube-play.png'),
                            const SizedBox(width: 10),
                            _buildSocialIcon('https://img.icons8.com/color/48/whatsapp.png'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 2,
                      child: _buildFooterCol('Seller Help', ['Seller Academy', 'University', 'Help Desk', 'Community']),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildFooterCol('Policies', ['Merchant Agreement', 'Privacy Policy', 'Terms of Service', 'Returns Policy']),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildFooterCol('Programs', ['Verified Seller', 'Premium Store', 'Wholesale B2B', 'Flash Sales']),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Get App', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 16),
                          Image.asset('assets/images/google_play.png', height: 28),
                          const SizedBox(height: 8),
                          Image.asset('assets/images/app_store.png', height: 28),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 40),
              const Divider(color: Colors.white12),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '© 2026 Elegant Marketplace. All rights reserved.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Row(
                    children: [
                      _buildPaymentBadge('assets/images/paypak.png'),
                      const SizedBox(width: 8),
                      _buildPaymentBadge('assets/images/jazzcash.png'),
                      const SizedBox(width: 8),
                      _buildPaymentBadge('assets/images/easypaisa.png'),
                      const SizedBox(width: 8),
                      _buildPaymentBadge('https://img.icons8.com/color/48/visa.png', isNetwork: true),
                      const SizedBox(width: 8),
                      _buildPaymentBadge('https://img.icons8.com/color/48/mastercard.png', isNetwork: true),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterCol(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 16),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GestureDetector(
                onTap: () {},
                child: Text(link, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ),
            )),
      ],
    );
  }

  Widget _buildSocialIcon(String url) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Colors.white10,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(6),
      child: Image.network(url, fit: BoxFit.contain),
    );
  }

  Widget _buildPaymentBadge(String path, {bool isNetwork = false}) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(5),
      child: ClipOval(
        child: isNetwork ? Image.network(path, fit: BoxFit.contain) : Image.asset(path, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkText,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            color: AppTheme.lightText,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
