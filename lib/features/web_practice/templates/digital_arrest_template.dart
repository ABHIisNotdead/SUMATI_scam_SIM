import 'dart:async';
import 'package:flutter/material.dart';

/// Generic unbranded Digital Arrest Clearance Portal Phishing Template.
/// Fictitious entity: "National Security Dept"
/// Displays fake court warrant, countdown timer, and bail deposit clearance form. Includes persistent simulation footer.
class DigitalArrestTemplate extends StatefulWidget {
  final Function(String reason, List<String> leaks) onCompromise;

  const DigitalArrestTemplate({
    super.key,
    required this.onCompromise,
  });

  @override
  State<DigitalArrestTemplate> createState() => _DigitalArrestTemplateState();
}

class _DigitalArrestTemplateState extends State<DigitalArrestTemplate> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _sigController = TextEditingController();
  int _secondsRemaining = 899; // 14:59
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
    _idController.dispose();
    _sigController.dispose();
    super.dispose();
  }

  String _formatTimer() {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _handleSubmit() {
    final leaks = <String>[];
    leaks.add('Submitted National Security ID Number (${_idController.text.isNotEmpty ? _idController.text : "98201-XXXX"})');
    leaks.add('Signed Fraudulent Bail Agreement (${_sigController.text.isNotEmpty ? _sigController.text : "Authorized"})');
    leaks.add('Agreed to transfer ₹50,000.00 to fake cyber police clearance escrow');

    widget.onCompromise('DIGITAL_ARREST_COMPROMISED', leaks);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Legal Agency Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Color(0xFFFBBF24), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'National Security Dept',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Central Cyber Order Clearance Desk',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Countdown Urgency Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.timer_outlined, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Warrant Enactment In:',
                      style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  _formatTimer(),
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Warrant Case Info Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Case Order No', 'CBI-ORD-8920/2026'),
                const Divider(height: 16),
                _buildInfoRow('Alleged Offense', 'Simulated Money Laundering & Telecom Fraud'),
                const Divider(height: 16),
                _buildInfoRow('Court Status', 'Digital Arrest in Progress'),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Escrow Clearance Fee:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      '₹50,000.00 (Refundable)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Form Input Fields
          _buildField(
            controller: _idController,
            label: 'Confirm National Identity / Passport Number',
            hint: 'e.g. 5421-XXXX-XXXX',
            icon: Icons.fingerprint_rounded,
          ),

          const SizedBox(height: 12),

          _buildField(
            controller: _sigController,
            label: 'Digital Name Signature',
            hint: 'Type your legal full name',
            icon: Icons.draw_rounded,
          ),

          const SizedBox(height: 24),

          // Submit Action
          ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), // Alert Red
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            child: const Text(
              'Sign Clearance & Deposit ₹50,000 Escrow',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 36),

          // Simulation Footer
          _buildSimulationFooter(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            ),
          ),
        ),
      ],
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
        '⚠️ SIMULATION ONLY • EDUCATIONAL DRILL\nIndian Law and police do not conduct "Digital Arrest" over phone or web forms. Fictitious scenario created by SUMATI.',
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

