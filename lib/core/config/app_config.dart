import 'package:flutter/foundation.dart';

/// Centralized application configuration.
/// Loads configuration values from environment variables via `--dart-define`.
class AppConfig {
  AppConfig._();

  /// Supabase Project URL loaded from environment variable `SUPABASE_URL`.
  static String get supabaseUrl {
    return const String.fromEnvironment('SUPABASE_URL');
  }

  /// Supabase Anon/Publishable Key loaded from environment variable `SUPABASE_ANON_KEY` or `SUPABASE_PUBLISHABLE_KEY`.
  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (key.isNotEmpty) return key;
    return const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  }

  /// Environment mode (e.g. `development`, `staging`, `production`).
  static String get environment {
    return const String.fromEnvironment('APP_ENV', defaultValue: 'development');
  }

  /// Returns true if app is running in production environment mode.
  static bool get isProduction => environment.toLowerCase() == 'production';

  /// Validates application configuration on startup.
  static void validate() {
    final url = supabaseUrl;
    final key = supabaseAnonKey;

    if (url.isEmpty || key.isEmpty) {
      throw StateError(
        'Missing required SUPABASE_URL / SUPABASE_ANON_KEY configuration. Pass via --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
      );
    }

    if (kDebugMode) {
      debugPrint('[AppConfig] Environment: $environment');
      debugPrint('[AppConfig] Supabase Endpoint: $url');
    }
  }
}
