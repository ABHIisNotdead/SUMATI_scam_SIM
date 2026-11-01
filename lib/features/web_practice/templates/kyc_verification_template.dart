import 'package:flutter/material.dart';

/// Generic unbranded KYC Verification Phishing Template.
/// Fictitious entity: "Global Citizen Bank"
/// Requests generic National ID and 6-digit OTP. Includes persistent simulation footer.
class KycVerificationTemplate extends StatefulWidget {
  final Function(String reason, List<String> leaks) onCompromise;

  const KycVerificationTemplate({
    super.key,
    required this.onCompromise,
  });

  @override
  State<KycVerificationTemplate> createState() => _KycVerificationTemplateState();
}

class _KycVerificationTemplateState extends State<KycVerificationTemplate> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final leaks = <String>[];
    leaks.add('Shared National ID Number (${_idController.text.isNotEmpty ? _idController.text : "9820-XXXX-1234"})');
    leaks.add('Shared 6-Digit Banking OTP (${_otpController.text.isNotEmpty ? _otpController.text : "589201"})');

    widget.onCompromise('KYC_OTP_SUBMITTED', leaks);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bank Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_rounded, color: Color(0xFF38BDF8), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Global Citizen Bank',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Customer Re-KYC Verification Portal',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Urgent Warning Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'URGENT: Your bank account will be suspended within 2 hours due to pending KYC compliance. Update details below.',
                    style: TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Form Fields
          _buildTextField(
            controller: _idController,
            label: 'National Identification / PAN / Aadhaar',
            hint: 'e.g. ABCD-1234-EFGH',
            icon: Icons.badge_outlined,
          ),

          const SizedBox(height: 14),

          _buildTextField(
            controller: _phoneController,
            label: 'Registered Mobile Number',
            hint: '+91 98XXX XXXXX',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 14),

          _buildTextField(
            controller: _otpController,
            label: '6-Digit One Time Password (OTP)',
            hint: 'Enter 6-digit code received via SMS',
            icon: Icons.password_rounded,
            keyboardType: TextInputType.number,
            isImportant: true,
          ),

          const SizedBox(height: 24),

          // Submit Action Button
          ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            child: const Text(
              'Verify Credentials & Unfreeze Account',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 36),

          // Ethical Simulation Footer
          _buildSimulationFooter(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isImportant = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isImportant ? FontWeight.w800 : FontWeight.w600,
            color: isImportant ? const Color(0xFFDC2626) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isImportant ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
              width: isImportant ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: isImportant ? const Color(0xFFDC2626) : const Color(0xFF64748B), size: 20),
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
        '⚠️ SIMULATION ONLY • EDUCATIONAL DRILL\nThis page is an unbranded security training drill generated by SUMATI. Never enter real passwords or banking OTPs.',
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

