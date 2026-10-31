import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/theme.dart';
import '../../../core/services/app_auth_provider.dart';
import '../../../core/services/app_state_provider.dart';
import '../../../core/utils/web_helper.dart';
import '../../../core/widgets/dev_version_banner.dart';
import 'seller_profile_screen.dart';
import 'seller_store_setup_screen.dart';
import '../widgets/dashboard/seller_dashboard_sidebar.dart';
import '../widgets/dashboard/seller_dashboard_header.dart';
import '../widgets/dashboard/seller_dashboard_overview.dart';
import '../widgets/dashboard/seller_dashboard_analytics.dart';
import '../widgets/dashboard/seller_dashboard_products.dart';
import '../widgets/dashboard/seller_dashboard_orders.dart';
import '../widgets/dashboard/seller_dashboard_marketing.dart';
import '../widgets/dashboard/seller_dashboard_finance.dart';
import '../widgets/dashboard/seller_dashboard_support.dart';
import '../widgets/dashboard/seller_dashboard_inventory.dart';
import '../widgets/dashboard/seller_dashboard_reviews.dart';
import '../widgets/dashboard/seller_dashboard_settings.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  String _activeSection = 'dashboard';
  String _activeSellerId = '';
  bool _hasNoStore = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncSectionFromHash();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user != null) {
          try {
            final res = await client
                .from('seller_stores')
                .select('id, shop_name, is_approved, kyc_status')
                .eq('owner_id', user.id)
                .maybeSingle();

            if (res != null && res['id'] != null) {
              final storeId = res['id'].toString();
              if (mounted) {
                final state = Provider.of<AppStateProvider>(context, listen: false);
                state.setLoggedInSellerId(storeId);
                setState(() {
                  _activeSellerId = storeId;
                  _hasNoStore = false;
                });
              }
              return;
            }
          } catch (e) {
            debugPrint('Error loading seller store: $e');
          }
        }
      } catch (_) {}

      if (!mounted) return;
      final state = Provider.of<AppStateProvider>(context, listen: false);
      if (state.loggedInSellerId != null && state.loggedInSellerId!.isNotEmpty) {
        setState(() {
          _activeSellerId = state.loggedInSellerId!;
          _hasNoStore = false;
        });
      } else {
        setState(() {
          _hasNoStore = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _syncSectionFromHash() {
    if (kIsWeb) {
      try {
        final hash = WebHelper.getHash();
        if (hash.contains('add-product')) {
          _activeSection = 'products_add';
        } else if (hash.contains('variations')) {
          _activeSection = 'products_variations';
        } else if (hash.contains('products')) {
          _activeSection = 'products_manage';
        } else if (hash.contains('returns')) {
          _activeSection = 'orders_returns';
        } else if (hash.contains('orders')) {
          _activeSection = 'orders_manage';
        } else if (hash.contains('customer-list')) {
          _activeSection = 'customers_list';
        } else if (hash.contains('chat')) {
          _activeSection = 'customers_chat';
        } else if (hash.contains('inventory')) {
          _activeSection = 'inventory_alerts';
        } else if (hash.contains('warehouse')) {
          _activeSection = 'inventory_warehouse';
        } else if (hash.contains('marketing')) {
          _activeSection = 'marketing_ads';
        } else if (hash.contains('vouchers')) {
          _activeSection = 'marketing_vouchers';
        } else if (hash.contains('analytics')) {
          _activeSection = 'analytics_performance';
        } else if (hash.contains('reports')) {
          _activeSection = 'analytics_reports';
        } else if (hash.contains('finance')) {
          _activeSection = 'finance_wallet';
        } else if (hash.contains('transactions')) {
          _activeSection = 'finance_history';
        } else if (hash.contains('reviews')) {
          _activeSection = 'reviews_product';
        } else if (hash.contains('store-rating')) {
          _activeSection = 'reviews_rating';
        } else if (hash.contains('settings')) {
          _activeSection = 'store_settings';
        } else if (hash.contains('store-design')) {
          _activeSection = 'store_design';
        } else if (hash.contains('account')) {
          _activeSection = 'settings_account';
        } else if (hash.contains('shipping')) {
          _activeSection = 'settings_shipping';
        } else if (hash.contains('support')) {
          _activeSection = 'support_tickets';
        } else if (hash.contains('kyc')) {
          _activeSection = 'support_kyc';
        } else {
          _activeSection = 'dashboard';
        }
      } catch (e) {
        debugPrint('Hash sync error: $e');
      }
    }
  }

  void _onSelectSection(String sectionId) {
    setState(() {
      _activeSection = sectionId;
    });
    if (kIsWeb) {
      try {
        WebHelper.setLocalStorage('apna_seller_active_section', sectionId);
        String routeName = 'dashboard';
        switch (sectionId) {
          case 'products_manage':
            routeName = 'products';
            break;
          case 'products_add':
            routeName = 'add-product';
            break;
          case 'products_variations':
            routeName = 'variations';
            break;
          case 'orders_manage':
            routeName = 'orders';
            break;
          case 'orders_returns':
            routeName = 'returns';
            break;
          case 'customers_list':
            routeName = 'customer-list';
            break;
          case 'customers_chat':
            routeName = 'chat';
            break;
          case 'inventory_alerts':
            routeName = 'inventory';
            break;
          case 'inventory_warehouse':
            routeName = 'warehouse';
            break;
          case 'marketing_ads':
            routeName = 'marketing';
            break;
          case 'marketing_vouchers':
            routeName = 'vouchers';
            break;
          case 'analytics_performance':
            routeName = 'analytics';
            break;
          case 'analytics_reports':
            routeName = 'reports';
            break;
          case 'finance_wallet':
            routeName = 'finance';
            break;
          case 'finance_history':
            routeName = 'transactions';
            break;
          case 'reviews_product':
            routeName = 'reviews';
            break;
          case 'reviews_rating':
            routeName = 'store-rating';
            break;
          case 'store_settings':
            routeName = 'settings';
            break;
          case 'store_design':
            routeName = 'store-design';
            break;
          case 'settings_account':
            routeName = 'account';
            break;
          case 'settings_shipping':
            routeName = 'shipping';
            break;
          case 'support_tickets':
            routeName = 'support';
            break;
          case 'support_kyc':
            routeName = 'kyc';
            break;
          default:
            routeName = 'dashboard';
        }
        final newHash = '#/seller/$routeName';
        WebHelper.replaceState(newHash);
      } catch (e) {
        debugPrint('Hash update error: $e');
      }
    }
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);
    final isWeb = MediaQuery.of(context).size.width > 600;
    const goldColor = Color(0xFFFDB913);

    User? currentUser = authProvider.currentUser;
    if (currentUser == null) {
      try {
        currentUser = Supabase.instance.client.auth.currentUser;
      } catch (_) {}
    }

    if (kDebugMode) {
      debugPrint('[APNA_BUILD] seller-auth-runtime-v3 CURRENT_BUILD');
      debugPrint('[SELLER_GUARD_RUNTIME] user=${currentUser?.id}, role=${authProvider.currentRole}, isAuth=${authProvider.isAuthenticated}, status=${authProvider.status}');
    }

    if (authProvider.isUnknown || authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isAuthenticated = authProvider.isAuthenticated || currentUser != null || state.isSellerLoggedIn;

    if (!isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seller Center'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please login to access the Seller Center dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.lightText),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/seller/login'),
                  child: const Text('Go to Seller Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final store = state.activeSellerStore ??
        (currentUser != null
            ? state.sellerController.getStoreByOwnerId(currentUser.id) ??
                state.sellerController.getStoreByEmail(currentUser.email ?? '')
            : null);

    if (store == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seller Center'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                authProvider.signOut();
                Navigator.pushReplacementNamed(context, '/seller/login');
              },
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront_outlined, size: 64, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  'No Seller Registration Found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You are signed in, but no seller store application was found for your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.lightText),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/seller/register'),
                  child: const Text('Register a New Store'),
                ),
                if (!AppConfig.isProduction || kDebugMode)
                  _buildDiagnosticPanel(context, authProvider, state, store),
              ],
            ),
          ),
        ),
      );
    }

    if (store.isSuspended) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seller Center — Account Status'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                authProvider.signOut();
                Navigator.pushReplacementNamed(context, '/seller/login');
              },
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block_outlined, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Store Account Suspended',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                const SizedBox(height: 8),
                Text(
                  'Store "${store.shopName}" has been suspended by marketplace governance. Please contact seller support.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.lightText),
                ),
                if (!AppConfig.isProduction || kDebugMode)
                  _buildDiagnosticPanel(context, authProvider, state, store),
              ],
            ),
          ),
        ),
      );
    }

    _activeSellerId = store.id;

    if (!store.isApproved) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seller Onboarding'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                Provider.of<AppAuthProvider>(context, listen: false).signOut();
                Navigator.pushReplacementNamed(context, '/seller/login');
              },
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: Colors.white,
              elevation: 8,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: isWeb ? 500 : double.infinity,
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_top_rounded, size: 72, color: Colors.amber),
                    const SizedBox(height: 20),
                    const Text(
                      'Application Pending Approval',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Thank you for registering your store "${store.shopName}". Your application is currently under review by our administration team.',
                      style: const TextStyle(fontSize: 14, color: AppTheme.lightText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildStatusRow('Store Status', 'Pending Approval', Colors.amber),
                    const SizedBox(height: 12),
                    _buildStatusRow('KYC Status', store.kycStatus, store.kycStatus == 'Approved' ? Colors.green : Colors.amber),
                    const SizedBox(height: 24),
                    const Text(
                      'We will contact you via email once your store has been verified and approved.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.lightText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Provider.of<AppAuthProvider>(context, listen: false).signOut();
                        Navigator.pushReplacementNamed(context, '/seller/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                    ),
                    if (!AppConfig.isProduction || kDebugMode)
                      _buildDiagnosticPanel(context, authProvider, state, store),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_hasNoStore) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 64, color: Color(0xFF059669)),
                const SizedBox(height: 16),
                const Text(
                  'No Seller Store Found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You are signed in, but you do not have a registered seller store yet. Complete registration to start selling on Apna Store.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Provider.of<AppAuthProvider>(context, listen: false).signOut();
                          if (context.mounted) Navigator.pushReplacementNamed(context, '/seller/login');
                        },
                        child: const Text('Sign Out'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/seller/register'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                        child: const Text('Register Store'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget activeBody;
    switch (_activeSection) {
      case 'dashboard':
        activeBody = SellerDashboardOverview(
          state: state,
          store: store,
          onSelectSection: _onSelectSection,
        );
        break;
      case 'products_manage':
        activeBody = SellerProductListSection(
          state: state,
          activeSellerId: _activeSellerId,
          onAddProduct: () => _onSelectSection('products_add'),
        );
        break;
      case 'products_variations':
        activeBody = SellerProductVariationsSection(state: state);
        break;
      case 'products_add':
        activeBody = SellerAddProductSection(state: state, activeSellerId: _activeSellerId);
        break;
      case 'orders_manage':
        activeBody = SellerOrdersManagementSection(state: state, activeSellerId: _activeSellerId);
        break;
      case 'orders_returns':
        activeBody = SellerReturnsDisputesSection(state: state, activeSellerId: _activeSellerId);
        break;
      case 'customers_list':
        activeBody = SellerCustomerListSection(state: state, activeSellerId: _activeSellerId);
        break;
      case 'customers_chat':
        activeBody = SellerCustomerMessagesSection(state: state, activeSellerId: _activeSellerId);
        break;
      case 'support_tickets':
        activeBody = SellerSupportTicketsSection(state: state, activeSellerId: _activeSellerId);
        break;
      case 'support_kyc':
        activeBody = SellerKycVerificationSection(state: state, activeSellerId: _activeSellerId);
        break;
      case 'inventory_alerts':
        activeBody = SellerStockAlertsSection(state: state, activeSellerId: _activeSellerId);
        break;
      case 'inventory_warehouse':
        activeBody = SellerWarehouseManagementSection(state: state, activeSellerId: _activeSellerId);
        break;
      case 'analytics_performance':
        activeBody = SellerPerformanceSummarySection(state: state, store: store, activeSellerId: _activeSellerId);
        break;
      case 'analytics_reports':
        activeBody = SellerSalesReportsSection(state: state, store: store, activeSellerId: _activeSellerId);
        break;
      case 'marketing_ads':
        activeBody = SellerAdsManagerSection(state: state);
        break;
      case 'marketing_vouchers':
        activeBody = SellerVouchersCouponsSection(state: state);
        break;
      case 'finance_wallet':
        activeBody = SellerWalletPayoutsSection(state: state, store: store, activeSellerId: _activeSellerId);
        break;
      case 'finance_history':
        activeBody = SellerTransactionHistorySection(state: state, store: store, activeSellerId: _activeSellerId);
        break;
      case 'store_settings':
        activeBody = const SellerStoreSetupScreen();
        break;
      case 'settings_account':
        activeBody = const SellerProfileScreen();
        break;
      case 'reviews_product':
        activeBody = SellerProductReviewsSection(state: state, activeSellerId: _activeSellerId);
        break;
      case 'reviews_rating':
        activeBody = SellerStoreRatingSection(state: state, store: store, activeSellerId: _activeSellerId);
        break;
      case 'store_design':
        activeBody = SellerStoreDesignSection(state: state, store: store);
        break;
      case 'settings_shipping':
        activeBody = SellerShippingSettingsSection(state: state, store: store);
        break;
      default:
        activeBody = SellerDashboardOverview(
          state: state,
          store: store,
          onSelectSection: _onSelectSection,
        );
    }

    return Column(
      children: [
        const DevVersionBanner(),
        Expanded(
          child: Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            appBar: SellerDashboardHeader(
              searchController: _searchController,
              activeSellerId: _activeSellerId,
              onSelectSeller: (val) {
                setState(() {
                  _activeSellerId = val;
                });
              },
              onSelectSection: _onSelectSection,
              isWeb: isWeb,
            ),
            drawer: !isWeb
                ? Drawer(
                    child: Container(
                      color: const Color(0xFF0B132B),
                      child: SellerDashboardSidebar(
                        activeSection: _activeSection,
                        onSelectSection: _onSelectSection,
                        goldColor: goldColor,
                      ),
                    ),
                  )
                : null,
            body: Row(
              children: [
                if (isWeb)
                  Container(
                    width: 250,
                    color: const Color(0xFF0B132B),
                    child: SellerDashboardSidebar(
                      activeSection: _activeSection,
                      onSelectSection: _onSelectSection,
                      goldColor: goldColor,
                    ),
                  ),
                const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE2E8F0)),
                Expanded(child: activeBody),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticPanel(
    BuildContext context,
    AppAuthProvider authProvider,
    AppStateProvider state,
    AppStore? store,
  ) {
    Session? supabaseSession;
    User? supabaseUser = authProvider.currentUser;
    try {
      final client = Supabase.instance.client;
      supabaseSession = client.auth.currentSession;
      supabaseUser = client.auth.currentUser ?? supabaseUser;
    } catch (_) {}
    final userIdSnippet = supabaseUser?.id != null
        ? (supabaseUser!.id.length >= 8 ? supabaseUser.id.substring(0, 8) : supabaseUser.id)
        : 'NONE';
    final storeIdSnippet = store?.id != null
        ? (store!.id.length >= 8 ? store.id.substring(0, 8) : store.id)
        : 'NONE';
    final ownerMatch = store != null && supabaseUser != null ? (store.ownerId == supabaseUser.id) : null;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report_outlined, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'SELLER AUTH DIAGNOSTIC PANEL (DEBUG)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('BUILD: seller-auth-runtime-v4', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          Text('SUPABASE SESSION: ${supabaseSession != null ? 'PRESENT' : 'NULL'}', style: TextStyle(color: supabaseSession != null ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          Text('SUPABASE USER: ${supabaseUser != null ? 'PRESENT' : 'NULL'}', style: TextStyle(color: supabaseUser != null ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          Text('USER ID: $userIdSnippet', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          Text('APP AUTH STATUS: ${authProvider.status.name}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          Text('APP AUTH isAuthenticated: ${authProvider.isAuthenticated}', style: TextStyle(color: authProvider.isAuthenticated ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          Text('APP AUTH ROLE: ${authProvider.currentRole ?? 'null'}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          Text('STORE FOUND: ${store != null}', style: TextStyle(color: store != null ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          Text('STORE APPROVED: ${store != null ? store.isApproved : 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          Text('STORE SUSPENDED: ${store != null ? store.isSuspended : 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          Text('STORE ID: $storeIdSnippet', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          Text('OWNER MATCH: ${ownerMatch != null ? ownerMatch : 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          Text('AppAuthProvider Hash: #${authProvider.hashCode}', style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () async {
              await authProvider.refreshUserRole();
              await state.sellerController.fetchStoresFromSupabase();
            },
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Refresh Auth State', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
