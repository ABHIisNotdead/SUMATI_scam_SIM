import 'dart:async';
import 'package:flutter/material.dart';

/// Simulated Phishing Template for Fake Virus Alert & Malicious APK Download.
/// Represents scenario `web_virus_download`.
/// Displays high-urgency system virus warning, countdown timer, fake damage progress,
/// and a prominent "Download Cleaner APK" button that triggers a simulated compromise.
class VirusAlertTemplate extends StatefulWidget {
  final Function(String reason, List<String> leaks) onCompromise;

  const VirusAlertTemplate({
    super.key,
    required this.onCompromise,
  });

  @override
  State<VirusAlertTemplate> createState() => _VirusAlertTemplateState();
}

class _VirusAlertTemplateState extends State<VirusAlertTemplate> {
  int _secondsRemaining = 59;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && _secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleDownloadApk() {
    final leaks = <String>[
      'Downloaded malicious APK file: Antivirus_Cleaner_Pro_v3.2.apk',
      'Granted installation permissions to unverified browser package',
      'Exposed device passwords, contacts, and SMS to banking trojan',
    ];
    widget.onCompromise('VIRUS_APK_DOWNLOADED', leaks);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Security Alert Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7F1D1D), // Dark Red
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Color(0xFFFBBF24), size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Android Security Scanner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'System Threat Detection Alert',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Critical Threat Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CRITICAL ALERT',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Auto-Damage in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '⚠️ (5) VIRUSES DETECTED ON YOUR PHONE!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your device is heavily infected with Trojan.Banker.Spyware. If not cleaned immediately, your banking passwords, photos, and Aadhaar documents will be leaked.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 14),

                // Damage Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('System Memory Damaged:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        Text('28.4%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 0.284,
                        minHeight: 8,
                        backgroundColor: Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Malware Items
                const Text('Identified Threats:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                _buildThreatItem('Trojan.Banker.AndroidOS', 'High Risk • Stealing NetBanking & UPI PINs'),
                _buildThreatItem('Spyware.Keylogger.Pro', 'Critical • Intercepting WhatsApp & SMS OTPs'),
                _buildThreatItem('Adware.AutoClicker.v2', 'Moderate • Depleting Battery & Data'),

                const SizedBox(height: 20),

                // High Pressure Download Button (The Trap)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    key: const Key('virus_download_apk_button'),
                    onPressed: _handleDownloadApk,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          '⬇️ DOWNLOAD CLEANER APK NOW',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Antivirus_Cleaner_Pro_v3.2.apk (14.2 MB)',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Simulation Educational Footer
          _buildSimulationFooter(),
        ],
      ),
    );
  }

  Widget _buildThreatItem(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bug_report_rounded, color: Color(0xFFDC2626), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        '⚠️ SIMULATION ONLY • EDUCATIONAL DRILL\nWeb browsers CANNOT scan your phone for viruses. Websites claiming your device is infected are phishing tricks designed to make you download malware. Never install APK files from unknown websites.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}

