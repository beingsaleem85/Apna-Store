/// Centralized application constants for marketplace rules and thresholds.
class AppConstants {
  AppConstants._();

  /// Standard flat shipping fee in PKR
  static const double standardShippingFee = 150.0;

  /// Order value threshold in PKR above which standard shipping is free
  static const double freeShippingThreshold = 1999.0;

  /// Platform baseline commission rate percentage (e.g. 10%)
  static const double defaultCommissionRate = 10.0;

  /// Standard pagination page size for list fetches
  static const int defaultPageSize = 20;

  /// App display name
  static const String appName = 'Elegant Marketplace';

  /// Standard customer care hotline
  static const String customerSupportPhone = '042-111-276-278';
}
