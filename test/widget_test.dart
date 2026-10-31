import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/main.dart';
import 'package:apna_store/core/services/supabase_service.dart';
import 'package:apna_store/core/services/supabase_seller_service.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/features/super_admin/services/super_admin_provider.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SupabaseService()),
          ChangeNotifierProvider(create: (_) => SupabaseSellerService()),
          ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ChangeNotifierProvider(create: (_) => SuperAdminProvider()),
        ],
        child: const ApnaStoreApp(),
      ),
    );
    await tester.pump();
  });
}
