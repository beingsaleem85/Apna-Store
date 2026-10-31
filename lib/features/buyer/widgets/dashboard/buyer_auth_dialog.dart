import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_auth_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class CustomerAuthDialogContent extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  const CustomerAuthDialogContent({super.key, required this.onAuthSuccess});

  @override
  State<CustomerAuthDialogContent> createState() => _CustomerAuthDialogContentState();
}

class _CustomerAuthDialogContentState extends State<CustomerAuthDialogContent> {
  String _viewMode = 'login'; // 'login', 'register'
  String _loginMethod = 'mobile'; // 'mobile' (OTP) or 'email'

  // Controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isOtpSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() {
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid Pakistani mobile number (+92 3XX XXXXXXX).');
      return;
    }
    setState(() {
      _isOtpSent = true;
      _errorMessage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mobile SMS login is in beta. Please switch to Email tab.'),
        backgroundColor: Color(0xFF059669),
      ),
    );
  }

  void _verifyOtp(AppStateProvider state) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mobile SMS verification is in beta. Please switch to Email tab.'),
        backgroundColor: Color(0xFF059669),
      ),
    );
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() => _errorMessage = null);
    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      await auth.login(email, password);
      widget.onAuthSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('AuthenticationFailure: ', ''));
      }
    }
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() => _errorMessage = null);
    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      await auth.signUp(
        email: email,
        password: password,
        fullName: name,
      );
      widget.onAuthSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('AuthenticationFailure: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context, listen: false);
    const primaryTeal = Color(0xFF004D40);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _viewMode == 'login' ? 'Customer Sign In' : 'Create Account',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTeal),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_viewMode == 'login') ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _loginMethod = 'mobile';
                          _errorMessage = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _loginMethod == 'mobile' ? primaryTeal : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_android, size: 16, color: _loginMethod == 'mobile' ? Colors.white : Colors.black87),
                              const SizedBox(width: 6),
                              Text(
                                'Mobile OTP',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _loginMethod == 'mobile' ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _loginMethod = 'email';
                          _errorMessage = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _loginMethod == 'email' ? primaryTeal : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.email_outlined, size: 16, color: _loginMethod == 'email' ? Colors.white : Colors.black87),
                              const SizedBox(width: 6),
                              Text(
                                'Email / Pass',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _loginMethod == 'email' ? Colors.white : Colors.black87,
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

              if (_loginMethod == 'mobile') ...[
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number (+92 3XX XXXXXXX)',
                    hintText: '03001234567',
                    prefixIcon: Icon(Icons.phone, color: Color(0xFF004D40)),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                if (_isOtpSent) ...[
                  TextField(
                    controller: _otpCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Enter 6-Digit OTP Code',
                      hintText: '123456',
                      prefixIcon: Icon(Icons.lock_clock, color: Color(0xFF004D40)),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _verifyOtp(state),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDB913),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Verify OTP & Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Send Verification Code (SMS)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ] else ...[
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email Address / Gmail',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(fontSize: 13, color: Colors.black54)),
                  TextButton(
                    onPressed: () => setState(() {
                      _viewMode = 'register';
                      _errorMessage = null;
                    }),
                    child: const Text('Register Now', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ] else if (_viewMode == 'register') ...[
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Address / Gmail',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number (+92 3XX XXXXXXX)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Register Account', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? ", style: TextStyle(fontSize: 13, color: Colors.black54)),
                  TextButton(
                    onPressed: () => setState(() {
                      _viewMode = 'login';
                      _errorMessage = null;
                    }),
                    child: const Text('Sign In', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void showCustomerAuthDialog(BuildContext context, {required VoidCallback onAuthSuccess}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => CustomerAuthDialogContent(onAuthSuccess: onAuthSuccess),
  );
}
