import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/user_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scam_shield_app_bar.dart';

class ScamReportsFeedScreen extends StatefulWidget {
  const ScamReportsFeedScreen({super.key});

  @override
  State<ScamReportsFeedScreen> createState() => _ScamReportsFeedScreenState();
}

class _ScamReportsFeedScreenState extends State<ScamReportsFeedScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _data = {'total_reports': 0, 'reports': []};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final res = await UserSyncService.fetchAllScamReports(limit: 50);
    if (mounted) {
      setState(() {
        _data = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = (_data['reports'] as List<dynamic>?) ?? [];
    final total = _data['total_reports'] ?? reports.length;
    final distinctPhones = _data['distinct_scammer_phones'] ?? 0;
    final distinctUpis = _data['distinct_scammer_upis'] ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const ScamShieldAppBar(
        title: 'Community Scam Reports',
        hideExit: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Notice Header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.security_update_warning_rounded, color: Color(0xFFB45309), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Crowdsourced Scam Intelligence: These reports were submitted by users to warn others and train Sumati AI scenario detection.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.35, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary Statistics
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile('Total Reports', '$total', Icons.report_problem_rounded, const Color(0xFF1E293B)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatTile('Scam Phones', '$distinctPhones', Icons.phone_disabled_rounded, const Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatTile('Fake UPIs', '$distinctUpis', Icons.account_balance_wallet_rounded, const Color(0xFFD97706)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Reports Log',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh feed',
                        onPressed: _loadReports,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (reports.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        children: const [
                          Icon(Icons.verified_user_outlined, size: 52, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No scam reports filed yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    ...reports.map((r) => _buildReportCard(r as Map<String, dynamic>)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> r) {
    final phone = r['scammer_phone']?.toString() ?? '';
    final upi = r['scammer_upi']?.toString() ?? '';
    final amount = r['scam_amount']?.toString() ?? '';
    final link = r['scammer_link']?.toString() ?? '';
    final story = r['story']?.toString() ?? '';
    final advice = r['ai_analysis']?.toString() ?? '';
    final id = r['id']?.toString() ?? '';
    final date = r['created_at']?.toString().split('T')[0] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Report #$id', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
              ),
              Text(date, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),

          // Detail Chips (Phone, UPI, Amount)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (phone.isNotEmpty)
                _buildChip(Icons.phone_rounded, 'Caller: $phone', () {
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number copied!')));
                }),
              if (upi.isNotEmpty)
                _buildChip(Icons.account_balance_wallet_rounded, 'UPI: $upi', () {
                  Clipboard.setData(ClipboardData(text: upi));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID copied!')));
                }),
              if (amount.isNotEmpty && amount != '0')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Loss: ₹$amount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
                ),
              if (link.isNotEmpty)
                _buildChip(Icons.link_rounded, link, null),
            ],
          ),
          const SizedBox(height: 12),

          // Story text
          if (story.isNotEmpty) ...[
            const Text('What happened:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(story, style: const TextStyle(fontSize: 14, color: AppTheme.onSurface, height: 1.35)),
            const SizedBox(height: 10),
          ],

          // AI Guidance
          if (advice.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.psychology_alt_rounded, size: 20, color: Color(0xFF15803D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sumati AI Guidance:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                        const SizedBox(height: 2),
                        Text(advice, style: const TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.35)),
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

  Widget _buildChip(IconData icon, String text, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF334155)),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF64748B)),
            ],
          ],
        ),
      ),
    );
  }
}

