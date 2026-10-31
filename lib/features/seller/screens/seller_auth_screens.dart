import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/app_auth_provider.dart';
import '../../../core/services/app_state_provider.dart';
import '../../../core/services/supabase_seller_service.dart';
import '../../../core/constants/theme.dart';

class SellerLoginScreen extends StatefulWidget {
  const SellerLoginScreen({super.key});

  @override
  State<SellerLoginScreen> createState() => _SellerLoginScreenState();
}

class _SellerLoginScreenState extends State<SellerLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Seller Login'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: MediaQuery.of(context).size.width > 600 ? 450 : double.infinity,
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.storefront, size: 64, color: AppTheme.primaryGreen),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to Seller Center',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to manage your online shop',
                      style: TextStyle(fontSize: 13, color: AppTheme.lightText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

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
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.lightText),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Please enter your email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.lightText),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Please enter your password';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: AppTheme.primaryGreen,
                              onChanged: (val) => setState(() => _rememberMe = val ?? false),
                            ),
                            const Text('Remember Me', style: TextStyle(color: AppTheme.darkText, fontSize: 13)),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/seller/forgot-password'),
                          child: const Text('Forgot Password?', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _performSellerLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 24),

                    // Registration link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Want to sell on Apna Store?', style: TextStyle(color: AppTheme.lightText, fontSize: 13)),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/seller/register');
                          },
                          child: const Text('Register Now', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _performSellerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final role = await authProvider.login(_emailController.text, _passwordController.text);

      if (!mounted) return;

      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        final normalizedRole = (role ?? '').toLowerCase();
        if (normalizedRole == 'seller' ||
            normalizedRole == 'admin' ||
            normalizedRole == 'superadmin' ||
            normalizedRole == 'super_admin' ||
            normalizedRole == 'owner') {
          setState(() => _isLoading = false);
          Navigator.pushReplacementNamed(context, '/seller/dashboard');
        } else {
          await authProvider.signOut();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'This account is not registered as a seller.';
            });
          }
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid email address or password.';
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

class SellerRegisterScreen extends StatefulWidget {
  const SellerRegisterScreen({super.key});

  @override
  State<SellerRegisterScreen> createState() => _SellerRegisterScreenState();
}

class _SellerRegisterScreenState extends State<SellerRegisterScreen> {
  int _currentStep = 0;
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();
  final _formKey4 = GlobalKey<FormState>();
  final _formKey5 = GlobalKey<FormState>();
  final _formKey6 = GlobalKey<FormState>();

  // Step 1 Controllers (Personal Info)
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2 Controllers (Business Info)
  final _storeNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  String _businessType = 'Sole Proprietorship';
  String _storeCategory = 'Fashion';
  final _countryController = TextEditingController(text: 'Pakistan');
  final _cityController = TextEditingController();
  final _businessAddressController = TextEditingController();

  // Step 3 Controllers (Identity Verification)
  final _cnicNumberController = TextEditingController();
  final _cnicFrontUrlController = TextEditingController();
  final _cnicBackUrlController = TextEditingController();
  final _selfieUrlController = TextEditingController();

  // Step 4 Controllers (Bank Details)
  String _bankName = 'Meezan Bank Limited';
  final _accountTitleController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ibanController = TextEditingController();

  // Step 5 Controllers (Store Setup)
  final _storeSlugController = TextEditingController();
  final _storeLogoController = TextEditingController();
  final _storeBannerController = TextEditingController();
  final _storeDescController = TextEditingController();
  final _pickupAddressController = TextEditingController();

  // Step 6 (Review & Submit)
  bool _acceptTerms = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _storeNameController.addListener(() {
      final text = _storeNameController.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
      _storeSlugController.text = text;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _storeNameController.dispose();
    _businessNameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _businessAddressController.dispose();
    _cnicNumberController.dispose();
    _cnicFrontUrlController.dispose();
    _cnicBackUrlController.dispose();
    _selfieUrlController.dispose();
    _accountTitleController.dispose();
    _accountNumberController.dispose();
    _ibanController.dispose();
    _storeSlugController.dispose();
    _storeLogoController.dispose();
    _storeBannerController.dispose();
    _storeDescController.dispose();
    _pickupAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Seller Registration Wizard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 6,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: isWeb ? 750 : double.infinity,
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStepIndicator(0, 'Personal', Icons.person_outline),
                        _buildStepDivider(),
                        _buildStepIndicator(1, 'Business', Icons.business_outlined),
                        _buildStepDivider(),
                        _buildStepIndicator(2, 'Identity', Icons.verified_user_outlined),
                        _buildStepDivider(),
                        _buildStepIndicator(3, 'Bank Details', Icons.account_balance_outlined),
                        _buildStepDivider(),
                        _buildStepIndicator(4, 'Store Setup', Icons.storefront_outlined),
                        _buildStepDivider(),
                        _buildStepIndicator(5, 'Review', Icons.check_circle_outline),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_currentStep == 0) _buildStep1PersonalForm(),
                  if (_currentStep == 1) _buildStep2BusinessForm(),
                  if (_currentStep == 2) _buildStep3IdentityForm(),
                  if (_currentStep == 3) _buildStep4BankForm(),
                  if (_currentStep == 4) _buildStep5StoreSetupForm(),
                  if (_currentStep == 5) _buildStep6ReviewSubmitForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title, IconData icon) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;

    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isCompleted
              ? Colors.green
              : isActive
                  ? AppTheme.primaryGreen
                  : Colors.black12,
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isCompleted || isActive ? Colors.white : AppTheme.lightText,
            size: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppTheme.primaryGreen : AppTheme.lightText,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Container(
      width: 24,
      height: 1,
      color: Colors.black12,
      margin: const EdgeInsets.symmetric(horizontal: 4).copyWith(bottom: 18),
    );
  }

  Widget _buildStep1PersonalForm() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Step 1: Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 4),
          const Text('Enter your personal seller contact details', style: TextStyle(fontSize: 12, color: AppTheme.lightText)),
          const SizedBox(height: 20),

          _buildTextField('Full Name', _fullNameController, Icons.person, (val) => val == null || val.isEmpty ? 'Please enter full name' : null),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField('Email Address', _emailController, Icons.email, (val) {
                  if (val == null || val.isEmpty || !val.contains('@')) return 'Enter valid email';
                  return null;
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField('Phone Number', _mobileController, Icons.phone, (val) => val == null || val.isEmpty ? 'Please enter mobile number' : null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPasswordField('Password', _passwordController),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPasswordField('Confirm Password', _confirmPasswordController, validateConfirm: true),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_formKey1.currentState!.validate()) {
                setState(() => _currentStep = 1);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Next: Business Info', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2BusinessForm() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Step 2: Business Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 4),
          const Text('Provide details about your shop and company entity', style: TextStyle(fontSize: 12, color: AppTheme.lightText)),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildTextField('Store Name', _storeNameController, Icons.storefront, (val) => val == null || val.isEmpty ? 'Required' : null),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField('Business Legal Name', _businessNameController, Icons.business, (val) => val == null || val.isEmpty ? 'Required' : null),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _businessType,
                  decoration: InputDecoration(
                    labelText: 'Business Type',
                    prefixIcon: const Icon(Icons.category_outlined, color: AppTheme.lightText),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ['Sole Proprietorship', 'Private Limited Company', 'Partnership', 'Individual']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) => setState(() => _businessType = val!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _storeCategory,
                  decoration: InputDecoration(
                    labelText: 'Business Category',
                    prefixIcon: const Icon(Icons.grid_view_outlined, color: AppTheme.lightText),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ['Fashion', 'Electronics', 'Groceries', 'Home & Living', 'Beauty', 'Mobiles', 'Laptops', 'Sports', 'Automotive', 'Books']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) => setState(() => _storeCategory = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTextField('Country', _countryController, Icons.public, (val) => null, enabled: false),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField('City', _cityController, Icons.location_city, (val) => val == null || val.isEmpty ? 'Enter city' : null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('Complete Address', _businessAddressController, Icons.place, (val) => val == null || val.isEmpty ? 'Enter street address' : null),

          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('Back'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey2.currentState!.validate()) {
                      setState(() => _currentStep = 2);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Next: Identity Verification', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3IdentityForm() {
    return Form(
      key: _formKey3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Step 3: Identity Verification (KYC)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 4),
          const Text('Upload CNIC/National Identity Card for merchant verification', style: TextStyle(fontSize: 12, color: AppTheme.lightText)),
          const SizedBox(height: 20),

          _buildTextField('CNIC / National ID Number', _cnicNumberController, Icons.badge_outlined, (val) => val == null || val.isEmpty ? 'Enter CNIC number' : null),
          const SizedBox(height: 16),
          _buildTextField('CNIC Front Image URL / Path', _cnicFrontUrlController, Icons.file_present_outlined, (val) => null),
          const SizedBox(height: 16),
          _buildTextField('CNIC Back Image URL / Path', _cnicBackUrlController, Icons.file_present_outlined, (val) => null),
          const SizedBox(height: 16),
          _buildTextField('Selfie Upload URL (Optional)', _selfieUrlController, Icons.camera_front_outlined, (val) => null),

          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('Back'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey3.currentState!.validate()) {
                      setState(() => _currentStep = 3);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Next: Bank Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4BankForm() {
    return Form(
      key: _formKey4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Step 4: Bank Account Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 4),
          const Text('Provide bank account details for weekly seller payout settlements', style: TextStyle(fontSize: 12, color: AppTheme.lightText)),
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
            value: _bankName,
            decoration: InputDecoration(
              labelText: 'Bank Name',
              prefixIcon: const Icon(Icons.account_balance_outlined, color: AppTheme.lightText),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: ['Meezan Bank Limited', 'Habib Bank Limited (HBL)', 'United Bank Limited (UBL)', 'MCB Bank', 'Allied Bank', 'Bank Alfalah', 'JazzCash', 'Easypaisa']
                .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) => setState(() => _bankName = val!),
          ),
          const SizedBox(height: 16),
          _buildTextField('Account Title', _accountTitleController, Icons.person_outline, (val) => val == null || val.isEmpty ? 'Enter account title' : null),
          const SizedBox(height: 16),
          _buildTextField('Account Number', _accountNumberController, Icons.numbers, (val) => val == null || val.isEmpty ? 'Enter account number' : null),
          const SizedBox(height: 16),
          _buildTextField('IBAN Number', _ibanController, Icons.payment_outlined, (val) => null),

          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 2),
                child: const Text('Back'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey4.currentState!.validate()) {
                      setState(() => _currentStep = 4);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Next: Store Setup', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep5StoreSetupForm() {
    return Form(
      key: _formKey5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Step 5: Store Branding & Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 4),
          const Text('Configure store branding, logo, banner, and pickup address', style: TextStyle(fontSize: 12, color: AppTheme.lightText)),
          const SizedBox(height: 20),

          _buildTextField('Store Slug URL (Auto-generated)', _storeSlugController, Icons.link, (val) => null, enabled: false),
          const SizedBox(height: 16),
          _buildTextField('Store Description', _storeDescController, Icons.description_outlined, (val) => null, maxLines: 2),
          const SizedBox(height: 16),
          _buildTextField('Store Logo URL / Image Link', _storeLogoController, Icons.image_outlined, (val) => null),
          const SizedBox(height: 16),
          _buildTextField('Store Banner URL / Image Link', _storeBannerController, Icons.panorama_outlined, (val) => null),
          const SizedBox(height: 16),
          _buildTextField('Order Pickup Address', _pickupAddressController, Icons.local_shipping_outlined, (val) => null),

          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 3),
                child: const Text('Back'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey5.currentState!.validate()) {
                      setState(() => _currentStep = 5);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Next: Review Application', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep6ReviewSubmitForm() {
    return Form(
      key: _formKey6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Step 6: Review Application & Submit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 4),
          const Text('Review your seller registration details before final submission', style: TextStyle(fontSize: 12, color: AppTheme.lightText)),
          const SizedBox(height: 20),

          Card(
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewRow('Seller Name', _fullNameController.text),
                  _buildReviewRow('Email Address', _emailController.text),
                  _buildReviewRow('Phone Number', _mobileController.text),
                  _buildReviewRow('Store Name', _storeNameController.text),
                  _buildReviewRow('Business Legal Name', _businessNameController.text),
                  _buildReviewRow('Business Type', _businessType),
                  _buildReviewRow('Category', _storeCategory),
                  _buildReviewRow('Location', '${_cityController.text}, ${_countryController.text}'),
                  _buildReviewRow('Bank Name', _bankName),
                  _buildReviewRow('Account Title', _accountTitleController.text.isNotEmpty ? _accountTitleController.text : _fullNameController.text),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Checkbox(
                value: _acceptTerms,
                activeColor: AppTheme.primaryGreen,
                onChanged: (val) => setState(() => _acceptTerms = val ?? false),
              ),
              const Expanded(
                child: Text(
                  'I agree to the Apna Store Seller Terms & Conditions and Commission Agreement Policy.',
                  style: TextStyle(fontSize: 12, color: AppTheme.darkText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 4),
                child: const Text('Back'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting || !_acceptTerms
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          final supabaseSeller = Provider.of<SupabaseSellerService>(context, listen: false);
                          final appState = Provider.of<AppStateProvider>(context, listen: false);

                          try {
                            await supabaseSeller.registerSeller(
                              email: _emailController.text,
                              password: _passwordController.text,
                              fullName: _fullNameController.text,
                              businessName: _businessNameController.text,
                              storeName: _storeNameController.text,
                              storeSlug: _storeSlugController.text,
                              mobileNumber: _mobileController.text,
                              country: _countryController.text,
                              city: _cityController.text,
                              businessAddress: _businessAddressController.text,
                              category: _storeCategory,
                              shopDescription: _storeDescController.text,
                            );

                            await appState.registerSeller(
                              fullName: _fullNameController.text,
                              businessName: _businessNameController.text,
                              storeName: _storeNameController.text,
                              email: _emailController.text,
                              mobileNumber: _mobileController.text,
                              country: _countryController.text,
                              city: _cityController.text,
                              businessAddress: _businessAddressController.text,
                              storeDescription: _storeDescController.text,
                              storeCategory: _storeCategory,
                              storeSlug: _storeSlugController.text,
                              storeContactNumber: _mobileController.text,
                              storeEmail: _emailController.text,
                              storeLogo: _storeLogoController.text,
                              storeBanner: _storeBannerController.text,
                            );

                            if (mounted) {
                              setState(() => _isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Registration submitted! Status: Pending Approval. Please sign in.'), backgroundColor: Colors.green),
                              );
                              Navigator.pushReplacementNamed(context, '/seller/login');
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Application', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.lightText)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              val.isNotEmpty ? val : 'Not specified',
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, String? Function(String?) validator, {bool enabled = true, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.lightText, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, {bool validateConfirm = false}) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.lightText, fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return 'Required';
        if (validateConfirm && val != _passwordController.text) return 'Passwords do not match';
        return null;
      },
    );
  }
}

class SellerForgotPasswordScreen extends StatefulWidget {
  const SellerForgotPasswordScreen({super.key});

  @override
  State<SellerForgotPasswordScreen> createState() => _SellerForgotPasswordScreenState();
}

class _SellerForgotPasswordScreenState extends State<SellerForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: isWeb ? 450 : double.infinity,
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Icon(Icons.lock_open, size: 64, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Reset Password',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your registered email address to receive a secure password reset link via Supabase Auth.',
                      style: TextStyle(fontSize: 13, color: AppTheme.lightText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (_isSubmitted) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.5)),
                        ),
                        child: const Text(
                          'If an account exists for this email address, a password reset link has been sent. Please check your inbox.',
                          style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter your email',
                          prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.lightText),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty || !value.contains('@')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handlePasswordReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handlePasswordReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    await authProvider.resetPasswordForEmail(_emailController.text);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSubmitted = true;
      });
    }
  }
}
