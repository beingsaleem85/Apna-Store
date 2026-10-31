import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';

class ResponsiveBuilder extends StatelessWidget {
  final Widget mobileLayout;
  final Widget webLayout;

  const ResponsiveBuilder({
    super.key,
    required this.mobileLayout,
    required this.webLayout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.tabletMin) {
          return webLayout;
        } else {
          return mobileLayout;
        }
      },
    );
  }
}
