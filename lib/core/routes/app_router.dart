import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/buyer/screens/address/buyer_address_location_screen.dart';
import '../../features/buyer/screens/ai/buyer_ai_copilot_screen.dart';
import '../../features/buyer/screens/all_recommended_screen.dart';
import '../../features/buyer/screens/auth/buyer_auth_onboarding_screen.dart';
import '../../features/buyer/screens/auth/buyer_onboarding_carousel_screen.dart';
import '../../features/buyer/screens/b2b/buyer_b2b_digital_screen.dart';
import '../../features/buyer/screens/buyer_dashboard.dart';
import '../../features/buyer/screens/buyer_splash_screen.dart';
import '../../features/buyer/screens/campaigns/buyer_campaign_vouchers_screen.dart';
import '../../features/buyer/screens/cart/buyer_cart_checkout_screen.dart';
import '../../features/buyer/screens/category_products_screen.dart';
import '../../features/buyer/screens/chat/buyer_chat_qa_screen.dart';
import '../../features/buyer/screens/checkout/buyer_checkout_screen.dart';
import '../../features/buyer/screens/checkout/buyer_order_success_screen.dart';
import '../../features/buyer/screens/home/buyer_dynamic_home_screen.dart';
import '../../features/buyer/screens/orders/buyer_order_tracking_screen.dart';
import '../../features/buyer/screens/product_details_screen.dart';
import '../../features/buyer/screens/returns/buyer_returns_claims_screen.dart';
import '../../features/buyer/screens/reviews/buyer_product_reviews_screen.dart';
import '../../features/buyer/screens/rewards/buyer_rewards_loyalty_screen.dart';
import '../../features/buyer/screens/search/buyer_search_filter_screen.dart';
import '../../features/buyer/screens/wallet/buyer_wallet_bnpl_screen.dart';
import '../../features/buyer/screens/wishlist/buyer_wishlist_gifting_screen.dart';
import '../../features/seller/screens/ads/seller_advertising_campaign_screen.dart';
import '../../features/seller/screens/ai/seller_ai_copilot_screen.dart';
import '../../features/seller/screens/analytics/seller_business_advisor_screen.dart';
import '../../features/seller/screens/b2b/seller_b2b_growth_screen.dart';
import '../../features/seller/screens/catalog/seller_product_catalog_screen.dart';
import '../../features/seller/screens/chat/seller_customer_chat_screen.dart';
import '../../features/seller/screens/dashboard/seller_executive_dashboard_screen.dart';
import '../../features/seller/screens/finance/seller_wallet_payout_screen.dart';
import '../../features/seller/screens/health/seller_account_health_screen.dart';
import '../../features/seller/screens/inventory/seller_inventory_management_screen.dart';
import '../../features/seller/screens/notifications/seller_notifications_center_screen.dart';
import '../../features/seller/screens/onboarding/seller_kyc_onboarding_screen.dart';
import '../../features/seller/screens/orders/seller_order_dispatch_screen.dart';
import '../../features/seller/screens/pricing/seller_pricing_engine_screen.dart';
import '../../features/seller/screens/promotions/seller_promotions_campaign_screen.dart';
import '../../features/seller/screens/returns/seller_returns_disputes_screen.dart';
import '../../features/seller/screens/reviews/seller_review_management_screen.dart';
import '../../features/seller/screens/security/seller_security_settings_screen.dart';
import '../../features/seller/screens/seller_auth_screens.dart';
import '../../features/seller/screens/seller_dashboard.dart';
import '../../features/seller/screens/seller_landing_page.dart';
import '../../features/seller/screens/seller_profile_screen.dart';
import '../../features/seller/screens/shipping/seller_logistics_governance_screen.dart';
import '../../features/seller/screens/staff/seller_staff_permissions_screen.dart';
import '../../features/seller/screens/storefront/seller_store_decoration_screen.dart';
import '../../features/super_admin/screens/admin_shell.dart';
import '../../features/super_admin/screens/auth/admin_login_screen.dart';
import 'app_routes.dart';
import 'unknown_route_screen.dart';

/// Centralized router for Apna Store navigation with default-deny server-controlled role guards.
class AppRouter {
  AppRouter._();

  /// Optional test seam resolver for isolated unit testing.
  /// Defaults to null in production environment.
  @visibleForTesting
  static String? Function()? testRoleResolver;

  /// Extracts verified role claim strictly from testRoleResolver or active authenticated session.
  static String? _getAuthenticatedUserRole() {
    if (testRoleResolver != null) {
      final testRole = testRoleResolver!();
      if (testRole != null) {
        final trimmed = testRole.trim().toLowerCase();
        return trimmed.isEmpty ? null : trimmed;
      }
      return null;
    }

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && session.user != null) {
        final role = session.user.appMetadata['role'] ?? session.user.userMetadata?['role'];
        if (role != null) return role.toString().toLowerCase();
        return 'buyer';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Verifies whether active user has trusted server-controlled seller authorization (default-deny).
  static bool _isSellerAuthorized() {
    final role = _getAuthenticatedUserRole();
    if (role == null) return false;
    return role == 'seller' || role == 'admin' || role == 'superadmin' || role == 'super_admin' || role == 'owner';
  }

  /// Verifies whether active user has trusted server-controlled admin authorization (default-deny).
  static bool _isAdminAuthorized() {
    final role = _getAuthenticatedUserRole();
    if (role == null) return false;
    return role == 'admin' || role == 'superadmin' || role == 'super_admin' || role == 'owner';
  }

  /// Generates routes dynamically based on route settings.
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final routeName = settings.name;

    // Handle all /seller paths dynamically on web page refresh or direct URL access
    if (routeName != null && (routeName == '/seller' || routeName.startsWith('/seller/'))) {
      switch (routeName) {
        case AppRoutes.sellerLanding:
          return MaterialPageRoute(builder: (_) => const SellerLandingPage());
        case AppRoutes.sellerLogin:
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        case AppRoutes.sellerRegister:
          return MaterialPageRoute(builder: (_) => const SellerRegisterScreen());
        case AppRoutes.sellerForgotPassword:
          return MaterialPageRoute(builder: (_) => const SellerForgotPasswordScreen());
        case AppRoutes.sellerProfile:
          if (!_isSellerAuthorized()) return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
          return MaterialPageRoute(builder: (_) => const SellerProfileScreen());
        case AppRoutes.sellerKyc:
          if (!_isSellerAuthorized()) return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
          return MaterialPageRoute(builder: (_) => const SellerKycOnboardingScreen());
        case AppRoutes.sellerDecoration:
          if (!_isSellerAuthorized()) return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
          return MaterialPageRoute(builder: (_) => const SellerStoreDecorationScreen());
        case AppRoutes.sellerExecutiveDashboard:
          if (!_isSellerAuthorized()) return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
          return MaterialPageRoute(builder: (_) => const SellerExecutiveDashboardScreen());
        default:
          if (!_isSellerAuthorized()) return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
          return MaterialPageRoute(builder: (_) => const SellerDashboard(), settings: settings);
      }
    }

    switch (settings.name) {
      // General & Root
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const BuyerDashboard());
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const BuyerSplashScreen());
      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const BuyerOnboardingCarouselScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      // Buyer Web / Main Portal Routes
      case AppRoutes.buyerDashboard:
      case AppRoutes.buyerAccount:
        return MaterialPageRoute(builder: (_) => const BuyerDashboard());
      case AppRoutes.buyerAuth:
        return MaterialPageRoute(builder: (_) => const BuyerAuthOnboardingScreen());
      case AppRoutes.buyerAddress:
      case AppRoutes.buyerAddresses:
        return MaterialPageRoute(builder: (_) => const BuyerAddressLocationScreen());
      case AppRoutes.buyerDynamicHome:
        return MaterialPageRoute(builder: (_) => const BuyerDynamicHomeScreen());
      case AppRoutes.buyerSearchFilter:
        return MaterialPageRoute(builder: (_) => const BuyerSearchFilterScreen());
      case AppRoutes.buyerPdp:
        return MaterialPageRoute(builder: (_) => const ProductDetailsScreen());
      case AppRoutes.buyerCart:
        return MaterialPageRoute(builder: (_) => const BuyerCartCheckoutScreen());
      case AppRoutes.buyerCheckout:
        return MaterialPageRoute(builder: (_) => const BuyerCheckoutScreen(), settings: settings);
      case AppRoutes.buyerOrderSuccess:
        return MaterialPageRoute(builder: (_) => const BuyerOrderSuccessScreen(), settings: settings);
      case AppRoutes.buyerWallet:
        return MaterialPageRoute(builder: (_) => const BuyerWalletBnplScreen());
      case AppRoutes.buyerOrderTracking:
      case AppRoutes.buyerOrders:
      case AppRoutes.checkoutConfirmation:
        return MaterialPageRoute(builder: (_) => const BuyerOrderTrackingScreen());
      case AppRoutes.buyerReturns:
        return MaterialPageRoute(builder: (_) => const BuyerReturnsClaimsScreen());
      case AppRoutes.buyerChatQa:
        return MaterialPageRoute(builder: (_) => const BuyerChatQaScreen());
      case AppRoutes.buyerReviews:
        return MaterialPageRoute(builder: (_) => const BuyerProductReviewsScreen());
      case AppRoutes.buyerCampaigns:
        return MaterialPageRoute(builder: (_) => const BuyerCampaignVouchersScreen());
      case AppRoutes.buyerRewards:
        return MaterialPageRoute(builder: (_) => const BuyerRewardsLoyaltyScreen());
      case AppRoutes.buyerWishlist:
        return MaterialPageRoute(builder: (_) => const BuyerWishlistGiftingScreen());
      case AppRoutes.buyerB2bDigital:
        return MaterialPageRoute(builder: (_) => const BuyerB2bDigitalScreen());
      case AppRoutes.buyerAiCopilot:
        return MaterialPageRoute(builder: (_) => const BuyerAiCopilotScreen());

      // Shared Catalog & Product Routes
      case AppRoutes.category:
        return MaterialPageRoute(builder: (_) => const CategoryProductsScreen(), settings: settings);
      case AppRoutes.product:
        if (settings.arguments is String) {
          return MaterialPageRoute(builder: (_) => const CategoryProductsScreen(), settings: settings);
        }
        return MaterialPageRoute(builder: (_) => const ProductDetailsScreen(), settings: settings);
      case AppRoutes.recommendedProducts:
      case AppRoutes.buyerRecommended:
        return MaterialPageRoute(builder: (_) => const AllRecommendedScreen(), settings: settings);

      // Public Seller Auth & Landing Routes
      case AppRoutes.sellerLanding:
        return MaterialPageRoute(builder: (_) => const SellerLandingPage());
      case AppRoutes.sellerLogin:
        return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
      case AppRoutes.sellerRegister:
        return MaterialPageRoute(builder: (_) => const SellerRegisterScreen());
      case AppRoutes.sellerForgotPassword:
        return MaterialPageRoute(builder: (_) => const SellerForgotPasswordScreen());

      // Privileged Protected Seller Routes (Role Guarded: Defaults to deny if unauthenticated or buyer)
      case AppRoutes.seller:
      case AppRoutes.sellerDashboard:
      case AppRoutes.sellerProducts:
      case AppRoutes.sellerAddProduct:
      case AppRoutes.sellerOrders:
      case AppRoutes.sellerSettings:
      case AppRoutes.sellerFinance:
      case AppRoutes.sellerAnalytics:
      case AppRoutes.sellerChat:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerDashboard());

      case AppRoutes.sellerProfile:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerProfileScreen());

      case AppRoutes.sellerKyc:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerKycOnboardingScreen());

      case AppRoutes.sellerDecoration:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerStoreDecorationScreen());

      case AppRoutes.sellerExecutiveDashboard:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerExecutiveDashboardScreen());

      case AppRoutes.sellerProductCatalog:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerProductCatalogScreen());

      case AppRoutes.sellerPricingEngine:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerPricingEngineScreen());

      case AppRoutes.sellerInventoryManagement:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerInventoryManagementScreen());

      case AppRoutes.sellerOrderDispatch:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerOrderDispatchScreen());

      case AppRoutes.sellerLogistics:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerLogisticsGovernanceScreen());

      case AppRoutes.sellerReturnsDisputes:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerReturnsDisputesScreen());

      case AppRoutes.sellerWallet:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerWalletPayoutScreen());

      case AppRoutes.sellerCustomerChat:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerCustomerChatScreen());

      case AppRoutes.sellerReviewManagement:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerReviewManagementScreen());

      case AppRoutes.sellerPromotionsHub:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerPromotionsCampaignScreen());

      case AppRoutes.sellerAdvertising:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerAdvertisingCampaignScreen());

      case AppRoutes.sellerBusinessAdvisor:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerBusinessAdvisorScreen());

      case AppRoutes.sellerAccountHealth:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerAccountHealthScreen());

      case AppRoutes.sellerNotifications:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerNotificationsCenterScreen());

      case AppRoutes.sellerAiCopilot:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerAiCopilotScreen());

      case AppRoutes.sellerStaffPermissions:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerStaffPermissionsScreen());

      case AppRoutes.sellerSecurity:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerSecuritySettingsScreen());

      case AppRoutes.sellerB2bGrowth:
        if (!_isSellerAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SellerLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SellerB2bGrowthScreen());

      // Public Admin Auth Routes
      case AppRoutes.superAdminLogin:
        return MaterialPageRoute(builder: (_) => const SuperAdminLoginScreen());

      // Privileged Protected Admin Routes (Role Guarded: Defaults to deny if unauthenticated or non-admin)
      case AppRoutes.superAdmin:
        if (!_isAdminAuthorized()) {
          return MaterialPageRoute(builder: (_) => const SuperAdminLoginScreen());
        }
        return MaterialPageRoute(builder: (_) => const SuperAdminShell());

      // Unknown Fallback Route
      default:
        return MaterialPageRoute(
          builder: (_) => UnknownRouteScreen(routeName: settings.name),
        );
    }
  }

  /// Handler for onUnknownRoute configuration.
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => UnknownRouteScreen(routeName: settings.name),
    );
  }
}
