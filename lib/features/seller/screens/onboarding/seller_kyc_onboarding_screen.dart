import 'package:flutter/material.dart';

class SellerKycOnboardingScreen extends StatefulWidget {
  const SellerKycOnboardingScreen({super.key});

  @override
  State<SellerKycOnboardingScreen> createState() => _SellerKycOnboardingScreenState();
}

class _SellerKycOnboardingScreenState extends State<SellerKycOnboardingScreen> {
  int _currentStep = 0;
  String _accountType = 'Individual Seller';

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _ntnController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();

  bool _cnicUploaded = false;
  bool _bankLetterUploaded = false;
  bool _policyAccepted = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _cnicController.dispose();
    _ntnController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Onboarding & KYC Verification'),
        backgroundColor: const Color(0xFF004D40),
        elevation: 2,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 3) {
            setState(() => _currentStep += 1);
          } else {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (!_policyAccepted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please accept the Marketplace Seller Policy to submit your KYC application.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('KYC Verification Documents Submitted for Review!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: [
          // Step 1: Select Account Type & OTP
          Step(
            title: const Text('Account Type & Verification'),
            isActive: _currentStep >= 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Your Seller Account Classification:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _accountType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: [
                    'Individual Seller',
                    'Registered Company (Pvt Ltd)',
                    'Official Brand Flagship Store',
                    'Wholesale Distributor',
                    'Cross-Border Seller'
                  ].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _accountType = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Phone Number (+92 300 1234567)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.sms),
                  label: const Text('Send SMS OTP Verification'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your mobile phone!')));
                  },
                ),
              ],
            ),
          ),

          // Step 2: Identity & Tax KYC Documents
          Step(
            title: const Text('Identity & Tax Documents (CNIC / NTN)'),
            isActive: _currentStep >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _cnicController,
                  decoration: const InputDecoration(
                    labelText: 'National Identity Card (CNIC #)',
                    hintText: '35201-1234567-1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ntnController,
                  decoration: const InputDecoration(
                    labelText: 'FBR Tax NTN Number (Optional for Individuals)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: Icon(_cnicUploaded ? Icons.check_circle : Icons.upload_file, color: _cnicUploaded ? Colors.green : const Color(0xFF004D40)),
                  label: Text(_cnicUploaded ? 'CNIC Image Uploaded' : 'Upload Front & Back CNIC Image'),
                  onPressed: () => setState(() => _cnicUploaded = !_cnicUploaded),
                ),
              ],
            ),
          ),

          // Step 3: Bank Account & IBAN Payout Details
          Step(
            title: const Text('Bank Payout IBAN & Settlement Details'),
            isActive: _currentStep >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _ibanController,
                  decoration: const InputDecoration(
                    labelText: 'Bank IBAN Number (e.g. PK36 HABB 0000 1234 5678 9012)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: Icon(_bankLetterUploaded ? Icons.check_circle : Icons.upload_file, color: _bankLetterUploaded ? Colors.green : const Color(0xFF004D40)),
                  label: Text(_bankLetterUploaded ? 'Cheque Copy Uploaded' : 'Upload Cheque / Bank Letter Copy'),
                  onPressed: () => setState(() => _bankLetterUploaded = !_bankLetterUploaded),
                ),
              ],
            ),
          ),

          // Step 4: Policy Agreement & Onboarding Checklist
          Step(
            title: const Text('Seller Agreement & Onboarding Checklist'),
            isActive: _currentStep >= 3,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  title: const Text('I agree to the Marketplace Seller Policy & Commission Agreement (10% Take-Rate)'),
                  value: _policyAccepted,
                  onChanged: (val) => setState(() => _policyAccepted = val ?? false),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber)),
                  child: const Row(
                    children: [
                      Icon(Icons.school, color: Colors.amber),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Seller University: Review our training video guide to upload your first product and fulfill orders.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
