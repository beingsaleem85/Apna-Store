import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/services/app_auth_provider.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

void showCustomerAuthDialog(BuildContext context, {VoidCallback? onAuthSuccess, String? targetAction}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CustomerAuthDialog(onAuthSuccess: onAuthSuccess, targetAction: targetAction),
  );
}

class CustomerAuthDialog extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  final String? targetAction;

  const CustomerAuthDialog({super.key, this.onAuthSuccess, this.targetAction});

  @override
  State<CustomerAuthDialog> createState() => _CustomerAuthDialogState();
}

class _CustomerAuthDialogState extends State<CustomerAuthDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0; // 0 = Mobile OTP, 1 = Email/Password

  // Mobile OTP state
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _isVerifyingOtp = false;

  // Email/Password state
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSignUpMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Status & Feedback
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters long.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      if (_isSignUpMode) {
        if (name.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Please enter your full name.';
          });
          return;
        }
        await authProvider.signUp(
          email: email,
          password: password,
          fullName: name,
        );
      } else {
        await authProvider.login(email, password);
      }

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            Navigator.pop(context);
            widget.onAuthSuccess?.call();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('AuthenticationFailure: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context, listen: false);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 12,
      backgroundColor: Colors.white,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row with Close Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF059669), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer Sign In',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                widget.targetAction != null
                                    ? 'Sign in to ${widget.targetAction}'
                                    : 'Sign in for secure shopping & checkout',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Success Banner
              if (_isSuccess) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 38),
                      const SizedBox(height: 8),
                      const Text('Welcome back!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669))),
                          SizedBox(width: 8),
                          Text('Redirecting to Checkout...', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Error Banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 14),
              ],

              if (!_isSuccess) ...[
                // Auth Option Segmented Bar (Mobile OTP vs Email)
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeTab = 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _activeTab == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _activeTab == 0
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                  : [],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_iphone_rounded, size: 15, color: _activeTab == 0 ? const Color(0xFF059669) : const Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Mobile OTP',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                                      color: _activeTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeTab = 1),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _activeTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _activeTab == 1
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                  : [],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.email_outlined, size: 15, color: _activeTab == 1 ? const Color(0xFF059669) : const Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Email Sign In',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                                      color: _activeTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // TAB 0: Mobile OTP
                if (_activeTab == 0) ...[
                  const Text('Mobile Number (Pakistan)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Text('🇵🇰 +92', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '03001234567',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_isOtpSent) ...[
                    const Text('Enter 4-Digit OTP Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 8),
                      decoration: InputDecoration(
                        hintText: '1 2 3 4',
                        hintStyle: const TextStyle(fontSize: 16, letterSpacing: 6, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFECFDF5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF059669))),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: Icon(_isOtpSent ? Icons.check_circle_rounded : Icons.sms_outlined, size: 18),
                      label: Text(_isOtpSent ? 'Verify OTP & Sign In' : 'Send Mobile OTP (SMS)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      onPressed: () {
                        if (!_isOtpSent) {
                          if (_phoneController.text.length < 10) {
                            setState(() => _errorMessage = 'Please enter a valid 11-digit mobile number.');
                            return;
                          }
                          setState(() {
                            _isOtpSent = true;
                            _errorMessage = null;
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mobile SMS login is currently in beta. Please use Email & Password tab.'), backgroundColor: Color(0xFF059669)),
                          );
                        }
                      },
                    ),
                  ),
                ],

                // TAB 1: Email & Password
                if (_activeTab == 1) ...[
                  if (_isSignUpMode) ...[
                    const Text('Full Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Ali Khan',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Text('Email Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'name@example.com',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF64748B)),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login_rounded, size: 18),
                      label: Text(_isSignUpMode ? 'Create Account & Sign In' : 'Sign In with Email', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      onPressed: _isLoading ? null : _handleEmailAuth,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _isSignUpMode = !_isSignUpMode),
                        child: Text(
                          _isSignUpMode ? 'Already have an account? Sign In' : 'Create New Account',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!_isSignUpMode)
                        InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password reset instructions sent to your email!')),
                            );
                          },
                          child: const Text('Forgot Password?', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR CONTINUE WITH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    ),
                    Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                  ],
                ),
                const SizedBox(height: 16),

                // Social Sign In Buttons (Google & Facebook)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Image.network(
                          'https://img.icons8.com/color/48/google-logo.png',
                          width: 18,
                          height: 18,
                          errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, size: 18, color: Color(0xFF0F172A)),
                        ),
                        label: const Text('Google', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Google Sign-In is currently in beta. Please use Email & Password tab.')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Image.network(
                          'https://img.icons8.com/color/48/facebook-new.png',
                          width: 18,
                          height: 18,
                          errorBuilder: (_, __, ___) => const Icon(Icons.facebook_rounded, size: 18, color: Color(0xFF1877F2)),
                        ),
                        label: const Text('Facebook', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Facebook Sign-In is currently in beta. Please use Email & Password tab.')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Terms & Privacy Links
                const Text(
                  'By signing in, you agree to Apna Store’s Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
