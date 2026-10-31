import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/services/app_auth_provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/super_admin_provider.dart';

class SuperAdminLoginScreen extends StatefulWidget {
  const SuperAdminLoginScreen({super.key});

  @override
  State<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Theme(
      data: SuperAdminTheme.themeData,
      child: Scaffold(
        backgroundColor: SuperAdminTheme.bgDark,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: SuperAdminTheme.cardDark,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: SuperAdminTheme.borderDark),
              ),
              child: Container(
                width: isWeb ? 480 : double.infinity,
                padding: const EdgeInsets.all(36.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Logo & Title
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: SuperAdminTheme.primaryTeal.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield, size: 54, color: SuperAdminTheme.secondaryGold),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Super Admin System Sign In',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SuperAdminTheme.textLight),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter your Super Admin credentials to access Marketplace Governance Controls.',
                        style: TextStyle(fontSize: 12, color: SuperAdminTheme.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email Field
                      const Text('Admin Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SuperAdminTheme.textLight)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'admin@apnastore.com',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.email_outlined, color: SuperAdminTheme.textMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          fillColor: SuperAdminTheme.bgDark,
                          filled: true,
                        ),
                        validator: (val) => val == null || !val.contains('@') ? 'Enter valid email' : null,
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      const Text('Admin Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SuperAdminTheme.textLight)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Enter password',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.lock_outline, color: SuperAdminTheme.textMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          fillColor: SuperAdminTheme.bgDark,
                          filled: true,
                        ),
                        validator: (val) => val == null || val.length < 6 ? 'Min 6 characters' : null,
                      ),
                      const SizedBox(height: 16),

                      // Remember Session Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: SuperAdminTheme.primaryTeal,
                            onChanged: (val) => setState(() => _rememberMe = val ?? true),
                          ),
                          const Expanded(
                            child: Text('Keep me signed in on this device', style: TextStyle(fontSize: 12, color: SuperAdminTheme.textMuted)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SuperAdminTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isLoading ? null : _performAdminLogin,
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Sign In to Super Admin System', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _performAdminLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final role = await authProvider.login(_emailController.text, _passwordController.text);

      if (!mounted) return;

      final normalizedRole = (role ?? '').toLowerCase();
      if (normalizedRole == 'admin' || normalizedRole == 'superadmin' || normalizedRole == 'super_admin' || normalizedRole == 'owner') {
        final adminProvider = Provider.of<SuperAdminProvider>(context, listen: false);
        adminProvider.initializeAdminSession(
          email: _emailController.text,
          backendRole: normalizedRole,
        );

        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/super-admin');
      } else {
        await authProvider.signOut();
        setState(() {
          _isLoading = false;
          _errorMessage = 'Access denied: Administrative privileges required.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid email address or password.';
        });
      }
    }
  }
}
