import 'package:flutter/material.dart';

/// Generic unbranded Electricity Bill Payment Gateway Phishing Template.
/// Fictitious entity: "Metro Power Co"
/// Form with fake UPI/Card entry and disconnection threat. Includes persistent simulation footer.
class ElectricityPaymentTemplate extends StatefulWidget {
  final Function(String reason, List<String> leaks) onCompromise;

  const ElectricityPaymentTemplate({
    super.key,
    required this.onCompromise,
  });

  @override
  State<ElectricityPaymentTemplate> createState() => _ElectricityPaymentTemplateState();
}

class _ElectricityPaymentTemplateState extends State<ElectricityPaymentTemplate> {
  int _selectedTab = 0; // 0 = UPI, 1 = Card
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  @override
  void dispose() {
    _upiController.dispose();
    _cardNumberController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final leaks = <String>[];
    if (_selectedTab == 0) {
      leaks.add('Entered Personal UPI ID / PIN (${_upiController.text.isNotEmpty ? _upiController.text : "user@okhdfc"})');
    } else {
      leaks.add('Entered Debit Card Credentials (${_cardNumberController.text.isNotEmpty ? _cardNumberController.text : "4532-XXXX-XXXX-8921"})');
      leaks.add('Revealed Card Security Code (CVV)');
    }
    leaks.add('Attempted unverified payment of ₹1,450.00 on fraudulent gateway');

    widget.onCompromise('BILL_PAYMENT_COMPROMISED', leaks);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Metro Power Co',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Emergency Bill Settlement Desk',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bill Details Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildRow('Consumer Account ID', 'MP-892019'),
                const Divider(height: 18),
                _buildRow('Disconnection Time', 'Tonight at 9:30 PM (Urgent)'),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Outstanding Due:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      '₹1,450.00',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Payment Method Selector Tabs
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('UPI / QR Pay')),
                  selected: _selectedTab == 0,
                  onSelected: (_) => setState(() => _selectedTab = 0),
                  selectedColor: const Color(0xFF0284C7),
                  labelStyle: TextStyle(
                    color: _selectedTab == 0 ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Debit / Credit Card')),
                  selected: _selectedTab == 1,
                  onSelected: (_) => setState(() => _selectedTab = 1),
                  selectedColor: const Color(0xFF0284C7),
                  labelStyle: TextStyle(
                    color: _selectedTab == 1 ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment Form
          if (_selectedTab == 0) ...[
            _buildField(
              controller: _upiController,
              label: 'UPI ID (VPA) or Mobile Number',
              hint: 'e.g. yourname@okhdfcbank',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ] else ...[
            _buildField(
              controller: _cardNumberController,
              label: '16-Digit Card Number',
              hint: 'XXXX-XXXX-XXXX-XXXX',
              icon: Icons.credit_card_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: TextEditingController(),
                    label: 'Expiry (MM/YY)',
                    hint: '12/28',
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _cvvController,
                    label: 'CVV / Security Code',
                    hint: '3 digits',
                    icon: Icons.lock_outline_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Submit Button
          ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A), // Green Pay
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            child: const Text(
              'Pay ₹1,450.00 & Avoid Power Disconnection',
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

  Widget _buildRow(String title, String val) {
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
    TextInputType keyboardType = TextInputType.text,
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
            keyboardType: keyboardType,
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
        '⚠️ SIMULATION ONLY • EDUCATIONAL DRILL\nMetro Power Co is a fictitious entity created by SUMATI for elderly scam prevention training. No real payment will occur.',
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

