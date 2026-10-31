import 'package:flutter/material.dart';

class SellerSecuritySettingsScreen extends StatefulWidget {
  const SellerSecuritySettingsScreen({super.key});

  @override
  State<SellerSecuritySettingsScreen> createState() => _SellerSecuritySettingsScreenState();
}

class _SellerSecuritySettingsScreenState extends State<SellerSecuritySettingsScreen> {
  bool _is2faEnabled = true;
  bool _isBiometricEnabled = true;
  bool _isSmsAlertsEnabled = true;

  final List<Map<String, String>> _sessions = [
    {'device': 'Chrome Browser (Windows 11)', 'ip': '182.180.12.44 (Lahore, PK)', 'time': 'Active Now (Current Device)', 'isCurrent': 'true'},
    {'device': 'Seller Mobile App (iPhone 15)', 'ip': '111.92.54.10 (Karachi, PK)', 'time': '2 hours ago', 'isCurrent': 'false'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security, Biometrics & Session Management'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Security Controls Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Authentication & Biometric Protections', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),

                    SwitchListTile(
                      dense: true,
                      secondary: const Icon(Icons.security, color: Color(0xFF004D40)),
                      title: const Text('Two-Factor Authentication (2FA)'),
                      subtitle: const Text('Require OTP code for payouts and store changes.'),
                      value: _is2faEnabled,
                      activeColor: const Color(0xFF004D40),
                      onChanged: (val) => setState(() => _is2faEnabled = val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      dense: true,
                      secondary: const Icon(Icons.fingerprint, color: Color(0xFF004D40)),
                      title: const Text('Biometric / Passkey Login'),
                      subtitle: const Text('Use Fingerprint or FaceID to sign into Seller Center.'),
                      value: _isBiometricEnabled,
                      activeColor: const Color(0xFF004D40),
                      onChanged: (val) => setState(() => _isBiometricEnabled = val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      dense: true,
                      secondary: const Icon(Icons.sms, color: Color(0xFF004D40)),
                      title: const Text('Unrecognized Login SMS Warnings'),
                      subtitle: const Text('Receive SMS alert if signed in from new IP or country.'),
                      value: _isSmsAlertsEnabled,
                      activeColor: const Color(0xFF004D40),
                      onChanged: (val) => setState(() => _isSmsAlertsEnabled = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Active Sessions Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Logged-in Active Device Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Revoke Other Sessions'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() {
                      _sessions.removeWhere((s) => s['isCurrent'] == 'false');
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Remote sessions terminated successfully!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sessions.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = _sessions[index];
                  final isCurrent = s['isCurrent'] == 'true';

                  return ListTile(
                    leading: Icon(isCurrent ? Icons.laptop : Icons.phone_iphone, color: const Color(0xFF004D40)),
                    title: Text(s['device']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('IP: ${s['ip']} | Last Active: ${s['time']}', style: const TextStyle(fontSize: 11)),
                    trailing: isCurrent
                        ? const Chip(label: Text('Current Session', style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Color(0xFF004D40))
                        : const Text('Remote', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
