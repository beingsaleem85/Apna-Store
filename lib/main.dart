import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/constants/theme.dart';
import 'core/controllers/catalog_controller.dart';
import 'core/controllers/cart_controller.dart';
import 'core/controllers/orders_controller.dart';
import 'core/controllers/seller_controller.dart';
import 'core/routes/app_router.dart';
import 'core/services/app_auth_provider.dart';
import 'core/services/supabase_service.dart';
import 'core/services/supabase_seller_service.dart';
import 'core/services/app_state_provider.dart';

import 'features/super_admin/services/super_admin_provider.dart';

import 'core/widgets/startup_failure_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool supabaseReady = true;
  String? initError;
  try {
    AppConfig.validate();
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  } catch (e, st) {
    supabaseReady = false;
    initError = e.toString();
    debugPrint('FATAL: Supabase initialisation failed: $e\n$st');
  }

  if (!supabaseReady) {
    runApp(StartupFailureApp(errorMessage: initError));
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => SupabaseService()),
        ChangeNotifierProvider(create: (_) => SupabaseSellerService()),
        ChangeNotifierProvider(create: (_) => CatalogController()),
        ChangeNotifierProvider(create: (_) => CartController()),
        ChangeNotifierProvider(create: (_) => OrdersController()),
        ChangeNotifierProvider(create: (_) => SellerController()),
        ChangeNotifierProxyProvider4<CatalogController, CartController, OrdersController, SellerController, AppStateProvider>(
          create: (ctx) => AppStateProvider(
            catalogController: Provider.of<CatalogController>(ctx, listen: false),
            cartController: Provider.of<CartController>(ctx, listen: false),
            ordersController: Provider.of<OrdersController>(ctx, listen: false),
            sellerController: Provider.of<SellerController>(ctx, listen: false),
          ),
          update: (ctx, catalog, cart, orders, seller, previous) {
            if (previous != null) {
              previous.updateDependencies(
                catalogController: catalog,
                cartController: cart,
                ordersController: orders,
                sellerController: seller,
              );
              return previous;
            }
            return AppStateProvider(
              catalogController: catalog,
              cartController: cart,
              ordersController: orders,
              sellerController: seller,
            );
          },
        ),
        ChangeNotifierProvider(create: (_) => SuperAdminProvider()),
      ],
      child: const ApnaStoreApp(),
    ),
  );
}

class ApnaStoreApp extends StatelessWidget {
  const ApnaStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elegant Marketplace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      onGenerateRoute: AppRouter.generateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
    );
  }
}
