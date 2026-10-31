import 'package:flutter/material.dart';

class StartupFailureApp extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const StartupFailureApp({
    super.key,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apna Store — Configuration Error',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: Scaffold(
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFEF4444), size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Backend Connection Required',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage ??
                      'Apna Store requires valid Supabase environment credentials to run. Please pass --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=... when launching the app.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (onRetry != null)
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
