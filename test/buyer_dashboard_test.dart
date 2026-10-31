import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/features/buyer/screens/buyer_dashboard.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/constants/theme.dart';

void main() {
  testWidgets('Test BuyerDashboard rendering', (WidgetTester tester) async {
    final state = AppStateProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppStateProvider>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const BuyerDashboard(),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(BuyerDashboard), findsOneWidget);
  });
}
