// ============================================================================
// APNA STORE — CENTRALIZED FEATURE FLAGS CONFIGURATION
// File: lib/core/config/feature_flags.dart
// ============================================================================

class FeatureFlags {
  /// External Push Notifications (FCM / APNs) integration status.
  /// Set to false as no external push provider SDK is configured.
  static const bool pushNotificationsEnabled = false;

  /// External Courier Partner API integration status.
  /// Set to false as manual fulfillment tracking is used.
  static const bool realCourierApiEnabled = false;

  /// Live GPS / Rider Map Location Tracking status.
  /// Set to false as no live rider location backend is configured.
  static const bool liveGpsTrackingEnabled = false;

  /// AI Copilot Features status.
  static const bool aiCopilotEnabled = false;

  /// Voice Assistant Features status.
  static const bool voiceAssistantEnabled = false;

  /// Hardware Printer / Airway Bill Printer Hardware Driver status.
  static const bool hardwarePrinterIntegrationEnabled = false;

  /// Hardware Barcode Scanner Hardware Driver status.
  static const bool barcodeScannerIntegrationEnabled = false;

  /// Sponsored Ads / CPC Ad Server Engine status.
  static const bool cpcAdsEnabled = false;

  /// Interim Payment Safety Guard: Online gateways (JazzCash, Easypaisa, Card).
  /// Kept strictly disabled until signature-verified webhooks and real gateway are deployed.
  static const bool onlinePaymentsEnabled = false;
}
