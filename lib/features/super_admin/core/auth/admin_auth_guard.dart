import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/super_admin_provider.dart';

class AdminAuthGuard {
  static bool isAuthenticated(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context, listen: false);
    return adminState.isLoggedIn;
  }

  static bool hasAccess(BuildContext context, String module, String action) {
    final adminState = Provider.of<SuperAdminProvider>(context, listen: false);
    return adminState.hasPermission(module, action);
  }

  static Widget guardRoute({
    required BuildContext context,
    required Widget targetScreen,
    String requiredModule = 'dashboard',
    String requiredAction = 'view',
  }) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    if (!adminState.isLoggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  'Super Admin Authentication Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please sign in with authorized Super Admin credentials to access this system module.',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Go to Super Admin Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () => Navigator.pushReplacementNamed(context, '/super-admin/login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!adminState.hasPermission(requiredModule, requiredAction)) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_outlined, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Insufficient Privilege Level',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your active admin role (${adminState.currentRole.name}) does not have "$requiredAction" permission for module "$requiredModule".',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                  onPressed: () => adminState.setActiveSection('dashboard'),
                  child: const Text('Back to Dashboard Overview'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return targetScreen;
  }
}
