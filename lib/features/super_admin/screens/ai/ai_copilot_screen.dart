import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';
import '../../../../core/services/app_state_provider.dart';
import '../../../../core/config/feature_flags.dart';

class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({super.key});

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final TextEditingController _queryController = TextEditingController();
  bool _isGenerating = false;
  String _aiResponse = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final adminState = Provider.of<SuperAdminProvider>(context);

    final pendingStoresCount = appState.stores.where((s) => !s.isApproved).length;
    final totalGmv = appState.orders.fold(0.0, (sum, o) => sum + o.productPrice);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            color: SuperAdminTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: SuperAdminTheme.borderDark)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: SuperAdminTheme.primaryTeal.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome_outlined, size: 36, color: SuperAdminTheme.secondaryGold),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Executive Copilot & Predictive Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: SuperAdminTheme.textLight)),
                        SizedBox(height: 4),
                        Text('Generate AI daily executive briefings, forecast category inventory demand surges, and run natural language admin commands.', style: TextStyle(fontSize: 12, color: SuperAdminTheme.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // AI Daily Briefing Card
          Card(
            color: SuperAdminTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: SuperAdminTheme.primaryTeal)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: SuperAdminTheme.secondaryGold, size: 20),
                          SizedBox(width: 8),
                          Text('AI Executive Daily Intelligence Briefing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Refresh AI Insights'),
                        style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primaryTeal),
                        onPressed: () {
                          if (!FeatureFlags.aiCopilotEnabled) {
                            SuperAdminDialogs.showToast(context, 'AI Copilot service is currently disabled (Feature Flag OFF). Real AI API required.');
                            return;
                          }
                          setState(() => _isGenerating = true);
                          Future.delayed(const Duration(milliseconds: 800), () {
                            if (mounted) {
                              setState(() => _isGenerating = false);
                              adminState.logAuditAction('AI_BRIEFING_REFRESH', 'Executive Copilot', 'Generated fresh AI daily briefing.');
                              SuperAdminDialogs.showToast(context, 'AI Daily Briefing Updated!');
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_isGenerating)
                    const LinearProgressIndicator(color: SuperAdminTheme.secondaryGold)
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: SuperAdminTheme.bgDark, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📊 Marketplace Health Summary (Gross GMV: Rs. ${totalGmv.toInt()})',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '• Demand Surge: Fashion & Apparel inventory demand expected to rise +35% in next 7 days.\n'
                            '• Action Required: $pendingStoresCount merchant stores awaiting KYC approval in governance queue.\n'
                            '• Risk Alert: 1 seller flagged for potential self-buying rating inflation.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Natural Language Query Assistant Desk
          Card(
            color: SuperAdminTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: SuperAdminTheme.borderDark)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ask AI Copilot (Natural Language Assistant)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'e.g. "Which category generated the highest commission this month?"',
                            hintStyle: TextStyle(color: SuperAdminTheme.textMuted),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Ask Copilot'),
                        style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primaryTeal, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
                        onPressed: () {
                          if (_queryController.text.isNotEmpty) {
                            setState(() {
                              _aiResponse = 'AI Answer: Based on current telemetry, Fashion & Apparel accounts for 42% of total marketplace GMV with Rs. 14,200 commission earned.';
                            });
                            adminState.logAuditAction('AI_QUERY', _queryController.text, 'Executed AI copilot query.');
                          }
                        },
                      ),
                    ],
                  ),

                  if (_aiResponse.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: SuperAdminTheme.bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: SuperAdminTheme.borderDark)),
                      child: Text(_aiResponse, style: const TextStyle(color: SuperAdminTheme.secondaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
