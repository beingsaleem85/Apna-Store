import 'package:flutter/material.dart';

class BuyerAuthOnboardingScreen extends StatefulWidget {
  const BuyerAuthOnboardingScreen({super.key});

  @override
  State<BuyerAuthOnboardingScreen> createState() => _BuyerAuthOnboardingScreenState();
}

class _BuyerAuthOnboardingScreenState extends State<BuyerAuthOnboardingScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isOtpSent = false;
  String _accountType = 'Personal'; // 'Personal' or 'Business'
  String _selectedLanguage = 'English'; // 'English', 'Urdu', 'Roman Urdu'
  final List<String> _selectedCategories = [];

  final List<String> _availableCategories = [
    'Women Fashion & Lawn',
    'Men Fashion & Suits',
    'Mobiles & Electronics',
    'Home & Appliances',
    'Beauty & Cosmetics',
    'Groceries & Essentials',
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Sign In & Registration'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account Type Switcher
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Personal Buyer', style: TextStyle(fontWeight: FontWeight.bold)),
                      selected: _accountType == 'Personal',
                      selectedColor: const Color(0xFF004D40),
                      labelStyle: TextStyle(color: _accountType == 'Personal' ? Colors.white : Colors.black87),
                      onSelected: (val) => setState(() => _accountType = 'Personal'),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Corporate / B2B Buyer', style: TextStyle(fontWeight: FontWeight.bold)),
                      selected: _accountType == 'Business',
                      selectedColor: const Color(0xFF004D40),
                      labelStyle: TextStyle(color: _accountType == 'Business' ? Colors.white : Colors.black87),
                      onSelected: (val) => setState(() => _accountType = 'Business'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Mobile OTP Authentication Section
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.phone_android, color: Color(0xFF004D40)),
                            SizedBox(width: 8),
                            Text('Fast Mobile OTP Login (Pakistan)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number (+92 3XX XXXXXXX)',
                            hintText: '03001234567',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.flag),
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_isOtpSent) ...[
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Enter 6-Digit SMS / WhatsApp OTP Code',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_clock),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(_isOtpSent ? Icons.check_circle : Icons.send),
                            label: Text(_isOtpSent ? 'Verify OTP & Continue' : 'Send SMS / WhatsApp OTP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004D40),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              if (!_isOtpSent) {
                                if (_phoneController.text.isNotEmpty) {
                                  setState(() => _isOtpSent = true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('OTP sent to your mobile number via SMS & WhatsApp!')),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Mobile Login Successful! Welcome to Apna Store.')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Social & Biometric Login Options
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                        label: const Text('Google Sign-In'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Signed in with Google!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.fingerprint, color: Color(0xFF004D40)),
                        label: const Text('Passkey / TouchID'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Biometric Authentication Successful!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Onboarding Preferences (Language & Categories)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Personalized Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        const Text('Preferred Interface Language:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 6),

                        Row(
                          children: ['English', 'Urdu', 'Roman Urdu'].map((lang) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(lang),
                                selected: _selectedLanguage == lang,
                                selectedColor: const Color(0xFF004D40),
                                labelStyle: TextStyle(color: _selectedLanguage == lang ? Colors.white : Colors.black87),
                                onSelected: (val) => setState(() => _selectedLanguage = lang),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        const Text('Favorite Shopping Categories:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 6),

                        Wrap(
                          spacing: 8,
                          children: _availableCategories.map((cat) {
                            final isSel = _selectedCategories.contains(cat);
                            return FilterChip(
                              label: Text(cat, style: const TextStyle(fontSize: 11)),
                              selected: isSel,
                              selectedColor: const Color(0xFF004D40),
                              labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedCategories.add(cat);
                                  } else {
                                    _selectedCategories.remove(cat);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
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
