import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/practice_tag.dart';
import '../../core/widgets/i_feel_worried_button.dart';
import '../../core/models/scenario.dart';
import '../../core/models/simulation_result.dart';

class WebPracticeScreen extends StatefulWidget {
  final Scenario? scenario;

  const WebPracticeScreen({super.key, this.scenario});

  @override
  State<WebPracticeScreen> createState() => _WebPracticeScreenState();
}

class _WebPracticeScreenState extends State<WebPracticeScreen> {
  bool _submittedForm = false;
  int _secondsRemaining = 899; // 14:59 for digital lock
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    if (widget.scenario?.id == 'web_digital_lock') {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _handleTrapAction(String reason, String fallbackMsg) {
    if (_submittedForm) return;
    setState(() => _submittedForm = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        SimulationResult.recordResult(
          scenarioTitle: widget.scenario?.title ?? 'Web Security Practice',
          channel: 'web',
          status: 'compromised',
        );
        context.replace('/debrief', extra: {
          'outcome': 'failure:$reason',
          'message': widget.scenario?.debriefFailure ?? fallbackMsg,
        });
      }
    });
  }

  void _handleSafeExit(String reason, String fallbackMsg) {
    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? 'Web Security Practice',
      channel: 'web',
      status: 'deflected',
    );
    context.replace('/debrief', extra: {
      'outcome': 'success:$reason',
      'message': widget.scenario?.debriefSuccess ?? fallbackMsg,
    });
  }

  @override
  Widget build(BuildContext context) {
    final scenarioId = widget.scenario?.id ?? '';
    final isDigitalLock = scenarioId == 'web_digital_lock';
    final isVirusDownload = scenarioId == 'web_virus_download';

    String displayUrl = 'http://secure-bank-update-login.in/kyc';
    if (isDigitalLock) {
      displayUrl = 'http://cyber-crime-cell-lock.gov-alert.in/device-seized';
    } else if (isVirusDownload) {
      displayUrl = 'http://android-virus-cleaner-booster.xyz/scan-results';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chrome Simulator'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleSafeExit('closed_tab', 'Excellent! You closed the unsafe website.'),
        ),
      ),
      body: Column(
        children: [
          const PracticeTag(),
          // Fake Address Bar
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_open, color: AppTheme.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayUrl,
                          style: const TextStyle(color: AppTheme.red, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: AppTheme.red.withValues(alpha: 0.1),
                  child: Row(
                    children: const [
                      Icon(Icons.warning, color: AppTheme.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: Unverified domain. Not an official government or secure site.',
                          style: TextStyle(color: AppTheme.red, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Dynamic Web Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: isDigitalLock
                  ? _buildDigitalLockContent()
                  : isVirusDownload
                      ? _buildVirusDownloadContent()
                      : _buildDefaultBankContent(),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Digital Lock Scenario (Fake Police Device Lock)
  Widget _buildDigitalLockContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(Icons.gavel, size: 54, color: Colors.white),
              const SizedBox(height: 12),
              const Text(
                '🚨 LAW ENFORCEMENT NOTICE\nDEVICE RESTRICTED UNDER CYBER ACT',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Time to Arrest: ${_formatTimer(_secondsRemaining)}',
                  style: const TextStyle(color: Colors.yellowAccent, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Central Cyber Division Seizure Order:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Your mobile device has been restricted due to unauthorized downloads. A court arrest warrant has been prepared. To stop police dispatch to your home address, pay the statutory fine of ₹15,000 immediately.',
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.payment),
          label: const Text('Pay ₹15,000 Fine via UPI Immediately', style: TextStyle(fontSize: 16)),
          onPressed: _submittedForm ? null : () => _handleTrapAction('paid_fine', 'Never pay fines on websites! Real police never lock phones or demand UPI transfers.'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.close),
          label: const Text('Close Tab & Exit Browser (Safe Action)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: () => _handleSafeExit('closed_tab', 'Great job! You closed the browser tab. Websites cannot lock your phone.'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.phone_in_talk, color: AppTheme.primaryTeal),
          label: const Text('Report to National Cyber Crime Helpline (1930)'),
          onPressed: () => _handleSafeExit('reported_1930', 'Excellent! Dialing 1930 connects you directly with the official Indian Cyber Crime Portal.'),
        ),
        const SizedBox(height: 24),
        const IFeelWorriedButton(),
      ],
    );
  }

  // 2. Virus Download Scenario (Fake Virus Alert & Harmful APK)
  Widget _buildVirusDownloadContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade800,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: const [
              Icon(Icons.bug_report, size: 54, color: Colors.white),
              SizedBox(height: 12),
              Text(
                '⚠️ CRITICAL WARNING: (5) VIRUSES FOUND!\nBATTERY & BANK DETAILS COMPROMISED',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Device Infection Report:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your Android system is 28.4% damaged by Trojan.Banker malware. Photos, OTPs, and WhatsApp chats are currently leaking. Download the antivirus cleaner APK immediately to save your phone.',
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 0.72,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Damage Level: High (72%)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('📥 Download Antivirus_Cleaner_Pro.apk', style: TextStyle(fontSize: 16)),
          onPressed: _submittedForm ? null : () => _handleTrapAction('downloaded_apk', 'Never download .apk files from websites! This is how scammers install spyware.'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_download),
          label: const Text('Install SecurityUpdate.apk (Recommended)', style: TextStyle(fontSize: 14)),
          onPressed: _submittedForm ? null : () => _handleTrapAction('downloaded_apk', 'Scammers disguise malware as security updates. Only install apps from the Google Play Store.'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.close),
          label: const Text('Close Page / Do Not Download (Safe Action)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: () => _handleSafeExit('refused_download', 'Superb! Websites cannot scan your phone. Any website claiming you have viruses is trying to trick you into downloading malware.'),
        ),
        const SizedBox(height: 24),
        const IFeelWorriedButton(),
      ],
    );
  }

  // 3. Default Bank Form Scenario
  Widget _buildDefaultBankContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.account_balance, size: 64, color: AppTheme.primaryTeal),
        const SizedBox(height: 16),
        const Text(
          'Metro Trust Bank - Urgent Verification',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Text(
          'Please enter your NetBanking ID, Password, and ATM PIN to update your account details immediately.',
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 24),
        TextField(
          decoration: InputDecoration(
            labelText: 'NetBanking Username',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password / ATM PIN',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _submittedForm ? null : () => _handleTrapAction('entered_credentials', 'Never enter passwords or PINs on unverified websites!'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
          child: const Text('Submit Details'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => _handleSafeExit('closed_page', 'Excellent! You closed the unsafe website without entering sensitive information.'),
          child: const Text('Close This Page Safely'),
        ),
        const SizedBox(height: 32),
        const IFeelWorriedButton(),
      ],
    );
  }
}
