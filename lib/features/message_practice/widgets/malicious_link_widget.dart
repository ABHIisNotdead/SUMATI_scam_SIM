import 'package:flutter/material.dart';

/// Reusable UI Card for Malicious Link Payloads sent by scammer AI agents.
/// Renders authentic link preview card with domain metadata, title, and blue underlined URL.
class MaliciousLinkWidget extends StatelessWidget {
  final String url;
  final String? title;
  final String? description;
  final String? domain;
  final VoidCallback? onTap;

  const MaliciousLinkWidget({
    super.key,
    required this.url,
    this.title,
    this.description,
    this.domain,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parsedDomain = domain ?? _extractDomain(url);
    final displayTitle = title ?? 'Secure Verification Portal';
    final displayDesc = description ?? 'Click to verify your credentials or resolve the urgent dispute.';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), // Slate 100
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top preview banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        parsedDomain,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),

              // Title and Description preview
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayDesc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Underlined blue URL
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  url,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0284C7), // Sky 600
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF0284C7),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _extractDomain(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      if (uri.host.isNotEmpty) return uri.host;
    } catch (_) {}
    return rawUrl;
  }
}

