import 'package:flutter/material.dart';

/// Reusable UI Card for Simulated QR Code Payloads (e.g. UPI fraud, fake refund verification, electricity deposit).
/// Renders authentic QR code visual with merchant details, amount, and an onTap callback.
class QrCodePayloadWidget extends StatelessWidget {
  final String payeeName;
  final String upiId;
  final String? amount;
  final String purpose;
  final VoidCallback? onTap;

  const QrCodePayloadWidget({
    super.key,
    this.payeeName = 'Cyber Verification Desk',
    this.upiId = 'verify.pool@oksbi',
    this.amount = '₹24,999.00',
    this.purpose = 'Official bail deposit / dispute fee',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 290),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: UPI / Merchant Branding
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'UPI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payeeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: Color(0xFF38BDF8),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Simulated Authentic QR Code
              Container(
                width: 170,
                height: 170,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                ),
                child: CustomPaint(
                  painter: _SimulatedQrPainter(),
                ),
              ),

              const SizedBox(height: 10),

              // UPI ID & Purpose
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Text(
                      upiId,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      purpose,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

              if (amount != null && amount!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Amount: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          amount!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // CTA Button: Scan & Pay / Open
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF0284C7)),
                    SizedBox(width: 6),
                    Text(
                      'Tap to Scan / Pay',
                      style: TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter that creates a clean, realistic QR code pattern
class _SimulatedQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    const blockSize = 6.0;
    final cols = (size.width / blockSize).floor();
    final rows = (size.height / blockSize).floor();

    // 1. Draw Corner Finder Patterns (Top-Left, Top-Right, Bottom-Left)
    _drawFinderPattern(canvas, 0, 0, blockSize, paint);
    _drawFinderPattern(canvas, (cols - 7) * blockSize, 0, blockSize, paint);
    _drawFinderPattern(canvas, 0, (rows - 7) * blockSize, blockSize, paint);

    // 2. Deterministic pseudo-random matrix grid
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Skip finder areas
        if ((r < 8 && c < 8) || (r < 8 && c >= cols - 8) || (r >= rows - 8 && c < 8)) {
          continue;
        }

        // Deterministic hash pattern for realistic barcode look
        final hash = ((r * 31 + c * 17 + (r ^ c) * 13) % 100);
        if (hash < 48) {
          canvas.drawRect(
            Rect.fromLTWH(c * blockSize, r * blockSize, blockSize - 0.5, blockSize - 0.5),
            paint,
          );
        }
      }
    }
  }

  void _drawFinderPattern(Canvas canvas, double x, double y, double bs, Paint paint) {
    // Outer 7x7 square
    canvas.drawRect(Rect.fromLTWH(x, y, 7 * bs, 7 * bs), paint);
    // Inner 5x5 white square
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(x + bs, y + bs, 5 * bs, 5 * bs), whitePaint);
    // Center 3x3 black square
    canvas.drawRect(Rect.fromLTWH(x + 2 * bs, y + 2 * bs, 3 * bs, 3 * bs), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
