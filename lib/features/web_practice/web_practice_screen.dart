import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/scenario.dart';
import '../../core/models/simulation_result.dart';
import '../../core/providers/os_notification_provider.dart';
import '../../core/widgets/global_notification_overlay.dart';
import '../../core/widgets/practice_tag.dart';
import 'templates/digital_arrest_template.dart';
import 'templates/electricity_payment_template.dart';
import 'templates/kyc_verification_template.dart';
import 'templates/virus_alert_template.dart';

/// Simulated Mobile Browser Shell.
/// Features a realistic browser chrome with top URL address bar, red "Not Secure" SSL tag,
/// back/refresh buttons, and renders native simulated phishing forms with zero HTML dependencies.
class WebPracticeScreen extends ConsumerStatefulWidget {
  final Scenario? scenario;

  const WebPracticeScreen({super.key, this.scenario});

  @override
  ConsumerState<WebPracticeScreen> createState() => _WebPracticeScreenState();
}

class _WebPracticeScreenState extends ConsumerState<WebPracticeScreen> {
  late String _currentUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = _resolveInitialUrl();
  }

  void _refreshPage() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  String _resolveInitialUrl() {
    final sId = (widget.scenario?.id ?? '').toLowerCase();
    final title = (widget.scenario?.title ?? '').toLowerCase();

    if (sId.contains('virus') || sId.contains('apk') || title.contains('virus')) {
      return 'http://android-virus-cleaner-booster.xyz/scan-results';
    } else if (sId.contains('lock') || sId.contains('arrest') || sId.contains('police') || sId.contains('cbi') || title.contains('lock') || title.contains('police')) {
      return 'http://cyber-crime-division-notice.gov-verify.in/device-lock';
    } else if (sId.contains('elec') || sId.contains('bill') || title.contains('elec') || title.contains('bill')) {
      return 'http://metro-power-bill-pay.in/verify';
    }
    return 'http://metro-trust-netbanking.portal-verify.in/login';
  }

  void _handleFormCompromised(String reason, List<String> leaks) {
    // Notify Orchestrator of trap compromise
    ref.read(osNotificationProvider.notifier).sendAppAction(
      sourceApp: 'Browser',
      action: 'compromise_alert',
      text: reason,
      extra: {'leaks': leaks, 'url': _currentUrl},
    );

    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? 'Web Security Practice',
      channel: 'web',
      status: 'compromised',
    );

    final hookDescription = _resolveHook();
    final giveawayDescription = _resolveGiveaway();

    // Immediately halt drill and route to Post-Scam Analytics Report
    context.replace('/debrief', extra: {
      'outcome': 'failure:compromised',
      'scenarioId': widget.scenario?.id,
      'hook': hookDescription,
      'leak': leaks.join(' • '),
      'giveaway': giveawayDescription,
      'customMessage': 'Caution! Submitting personal information on unverified HTTP websites exposes your funds to fraudsters.',
    });
  }

  String _resolveHook() {
    final sId = (widget.scenario?.id ?? '').toLowerCase();
    final title = (widget.scenario?.title ?? '').toLowerCase();

    if (sId.contains('virus') || sId.contains('apk') || title.contains('virus')) {
      return 'Fabricated Device Danger & Virus Scare: False claims that 5 viruses are destroying battery and leaking passwords to force downloading malicious APK cleaner.';
    } else if (sId.contains('lock') || sId.contains('arrest') || sId.contains('police') || sId.contains('cbi') || title.contains('lock') || title.contains('police')) {
      return 'Coercive Legal Authority & Device Lock: Fake police lock screen threatening imminent arrest unless an instant UPI fine is paid.';
    } else if (sId.contains('elec') || sId.contains('bill') || title.contains('elec') || title.contains('bill')) {
      return 'Artificial Fear of Service Cutoff: Threatened power disconnection tonight at 9:30 PM to incite urgency.';
    }
    return 'Account Panic & Fear of Asset Freeze: Claimed bank accounts would be locked without immediate NetBanking credential update.';
  }

  String _resolveGiveaway() {
    return 'Unsecured HTTP Protocol ("Not Secure" warning in address bar), mismatched domain name, and demand for immediate confidential OTP/Card codes.';
  }

  void _onSafeExit() {
    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? 'Web Security Practice',
      channel: 'web',
      status: 'deflected',
    );

    context.replace('/debrief', extra: {
      'outcome': 'success:deflected',
      'scenarioId': widget.scenario?.id,
      'hook': _resolveHook(),
      'leak': 'None! You identified the suspicious browser URL and exited safely.',
      'giveaway': _resolveGiveaway(),
      'customMessage': 'Outstanding defense! You noticed the suspicious website indicators and refused to submit sensitive details.',
    });
  }

  void _onReportScam() {
    SimulationResult.recordResult(
      scenarioTitle: widget.scenario?.title ?? 'Web Security Practice',
      channel: 'web',
      status: 'deflected',
    );

    context.replace('/debrief', extra: {
      'outcome': 'success:deflected',
      'scenarioId': widget.scenario?.id,
      'hook': _resolveHook(),
      'leak': 'None! You reported the fake phishing website.',
      'giveaway': _resolveGiveaway(),
      'customMessage': 'Outstanding defense! You recognized the fraudulent website and reported the fraud.',
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlobalNotificationOverlay(
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Column(
          children: [
            // Legal Practice Safety Tag
            const PracticeTag(),

            // Top Mobile Browser Chrome & URL Bar
            _buildBrowserTopBar(),

            // Web Page Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
                  : _buildActiveWebTemplate(),
            ),

            // Bottom Browser Controls Dock
            _buildBrowserBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowserTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Close and Exit Button
          IconButton(
            key: const Key('web_close_button'),
            icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF334155)),
            onPressed: _onSafeExit,
            tooltip: 'Close and Exit / बाहर निकलें',
          ),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Red "Not Secure" SSL Warning Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text(
                          'Not Secure',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // URL
                  Expanded(
                    child: Text(
                      _currentUrl,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
                    onPressed: _refreshPage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Report Fake Website Button
          TextButton.icon(
            key: const Key('web_report_scam_button'),
            onPressed: _onReportScam,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFECACA)),
              ),
            ),
            icon: const Icon(Icons.shield_rounded, size: 15, color: Color(0xFFDC2626)),
            label: const Text(
              'Report',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWebTemplate() {
    final sId = (widget.scenario?.id ?? '').toLowerCase();
    final title = (widget.scenario?.title ?? '').toLowerCase();

    if (sId.contains('virus') || sId.contains('apk') || title.contains('virus')) {
      return VirusAlertTemplate(
        onCompromise: _handleFormCompromised,
      );
    } else if (sId.contains('lock') || sId.contains('arrest') || sId.contains('police') || sId.contains('cbi') || title.contains('lock') || title.contains('police')) {
      return DigitalArrestTemplate(
        onCompromise: _handleFormCompromised,
      );
    } else if (sId.contains('elec') || sId.contains('bill') || title.contains('elec') || title.contains('bill')) {
      return ElectricityPaymentTemplate(
        onCompromise: _handleFormCompromised,
      );
    }
    return KycVerificationTemplate(
      onCompromise: _handleFormCompromised,
    );
  }

  Widget _buildBrowserBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF64748B)),
            onPressed: _onSafeExit,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFFCBD5E1)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF64748B), width: 1.5),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              '1',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
