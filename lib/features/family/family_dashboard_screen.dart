import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/models/simulation_result.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/services/user_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scam_shield_app_bar.dart';

class FamilyDashboardScreen extends ConsumerStatefulWidget {
  const FamilyDashboardScreen({super.key});

  @override
  ConsumerState<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends ConsumerState<FamilyDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _seniorPhoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  bool _isConnecting = false;
  String? _connectError;
  Map<String, dynamic>? _connectedSeniorData;
  String? _pairedPhone;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedConnection();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _seniorPhoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _loadSavedConnection() {
    final box = Hive.isBoxOpen('preferences') ? Hive.box('preferences') : null;
    final savedPhone = box?.get('connected_senior_phone') as String?;
    if (savedPhone != null && savedPhone.isNotEmpty) {
      _pairedPhone = savedPhone;
      _seniorPhoneController.text = savedPhone;
      _refreshSeniorData(savedPhone);
    }
  }

  Future<void> _refreshSeniorData(String phone) async {
    setState(() => _isConnecting = true);
    final data = await UserSyncService.fetchSeniorStatus(phone);
    if (mounted) {
      setState(() {
        _isConnecting = false;
        if (data != null) {
          _connectedSeniorData = data;
          _connectError = null;
        } else {
          _connectError = 'Could not sync with senior account. Please verify the phone number.';
        }
      });
    }
  }

  Future<void> _handleConnect() async {
    final phone = _seniorPhoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty || pin.isEmpty) {
      setState(() => _connectError = 'Please enter both Senior Mobile Number and 4-digit PIN.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isConnecting = true;
      _connectError = null;
    });

    final res = await UserSyncService.authorizeFamilyConnect(
      seniorPhone: phone,
      pin: pin,
      familyName: 'Family Member',
    );

    if (!mounted) return;

    if (res['authorized'] == true) {
      final box = Hive.isBoxOpen('preferences') ? Hive.box('preferences') : null;
      box?.put('connected_senior_phone', phone);

      setState(() {
        _isConnecting = false;
        _pairedPhone = phone;
        _connectedSeniorData = res['data'] as Map<String, dynamic>?;
        _connectError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected to Senior successfully! • परिवार से सुरक्षित लिंक हुआ')),
      );
    } else {
      setState(() {
        _isConnecting = false;
        _connectError = res['message'] as String? ?? 'Invalid PIN or phone number.';
      });
    }
  }

  void _disconnectSenior() {
    final box = Hive.isBoxOpen('preferences') ? Hive.box('preferences') : null;
    box?.delete('connected_senior_phone');
    setState(() {
      _pairedPhone = null;
      _connectedSeniorData = null;
      _pinController.clear();
      _connectError = null;
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatChannel(String channel, String lang) {
    switch (channel.toLowerCase()) {
      case 'call':
        return UiStrings.get(lang, 'phone_call');
      case 'whatsapp':
        return 'WhatsApp';
      case 'sms':
        return UiStrings.get(lang, 'sms_message');
      case 'web':
        return UiStrings.get(lang, 'web_security');
      default:
        return channel.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(preferencesProvider).appLanguage;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: ScamShieldAppBar(
        title: UiStrings.get(lang, 'family_dashboard'),
        hideExit: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, semanticLabel: 'Home'),
            tooltip: UiStrings.get(lang, 'back_home'),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode Tabs: Connected Senior (Database) vs Local Device History
          Container(
            color: AppTheme.surfaceContainerLowest,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.onSurfaceVariant,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  icon: Icon(Icons.family_restroom_rounded),
                  text: 'Connected Senior (Sync)',
                ),
                Tab(
                  icon: Icon(Icons.phone_android_rounded),
                  text: 'Local Device History',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConnectedSeniorTab(lang),
                _buildLocalHistoryTab(lang),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Connected Senior via SQLite Database ───────────────────────────
  Widget _buildConnectedSeniorTab(String lang) {
    if (_pairedPhone == null || _connectedSeniorData == null) {
      return _buildConnectForm(lang);
    }
    return _buildRemoteSeniorDashboard(lang);
  }

  Widget _buildConnectForm(String lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.shield_rounded, color: Colors.white, size: 36),
                SizedBox(height: 12),
                Text(
                  'Family Connect • परिवार सुरक्षा लिंक',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'Remotely monitor your senior\'s scam safety score, drill history, and reported threats using their phone number and security PIN.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Input Form Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect to Senior\'s Device',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),

                // Mobile number field
                TextField(
                  controller: _seniorPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Senior Mobile Number / मोबाइल नंबर',
                    hintText: 'e.g. 9820123456',
                    prefixIcon: const Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // PIN field
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: '4-Digit Security PIN / सुरक्षा पिन',
                    hintText: 'e.g. 5821',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '🔒 The 4-digit PIN is displayed on the senior\'s Sumati app under Profile / Family button.',
                  style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),

                if (_connectError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF87171)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _connectError!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Connect Button
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _handleConnect,
                    icon: _isConnecting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.link_rounded, size: 22),
                    label: const Text('Connect & View Safety Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryContainer,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteSeniorDashboard(String lang) {
    final senior = _connectedSeniorData?['senior'] as Map<String, dynamic>? ?? {};
    final drills = (_connectedSeniorData?['drills'] as List<dynamic>?) ?? [];
    final reports = (_connectedSeniorData?['reports'] as List<dynamic>?) ?? [];

    final seniorName = senior['name']?.toString() ?? 'Senior';
    final score = senior['safety_score'] as int? ?? 100;
    final totalDrills = senior['total_drills'] as int? ?? drills.length;
    final avoidedDrills = senior['avoided_drills'] as int? ?? drills.where((d) => (d as Map)['status'] == 'deflected' || d['status'] == 'avoided').length;
    final compromisedDrills = math.max(0, totalDrills - avoidedDrills);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connected Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monitoring: $seniorName',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF047857)),
                      ),
                      Text(
                        'Mobile: $_pairedPhone • Live Database Sync',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF065F46)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF047857)),
                  tooltip: 'Refresh Status',
                  onPressed: () => _refreshSeniorData(_pairedPhone!),
                ),
                IconButton(
                  icon: const Icon(Icons.link_off_rounded, color: Color(0xFFDC2626)),
                  tooltip: 'Disconnect',
                  onPressed: _disconnectSenior,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Safety Scorecard Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Senior Safety Scorecard (Live Sync)',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '$seniorName\'s Protection Reflex',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AnimatedScoreRing(score: score, lang: lang),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetricRow(label: 'Total Drills', value: '$totalDrills', color: Colors.white),
                        const SizedBox(height: 12),
                        _buildMetricRow(label: 'Avoided', value: '$avoidedDrills', color: const Color(0xFF4ADE80)),
                        const SizedBox(height: 12),
                        _buildMetricRow(label: 'Compromised', value: '$compromisedDrills', color: const Color(0xFFF87171)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Reported Scams & Alerts Section (if senior filed any)
          if (reports.isNotEmpty) ...[
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                SizedBox(width: 8),
                Text('Senior\'s Reported Scam Attempts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            ...reports.map((rep) {
              final r = rep as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Caller: ${r['scammer_phone'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
                        Text(r['created_at']?.toString().split('T')[0] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    if (r['scammer_upi'] != null && r['scammer_upi'].toString().isNotEmpty)
                      Text('Fraud UPI: ${r['scammer_upi']}', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                    const SizedBox(height: 4),
                    Text(r['story'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Recent Drill Activity Feed
          const Text('Recent Drill Practice Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (drills.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No practice simulations recorded in database yet.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...drills.map((d) {
              final drill = d as Map<String, dynamic>;
              final status = drill['status']?.toString().toLowerCase() ?? '';
              final isAvoided = status == 'deflected' || status == 'avoided' || status == 'survived';
              final channel = drill['channel']?.toString() ?? 'Call';
              final title = drill['scenario_title']?.toString() ?? 'Scam Simulation';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isAvoided ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isAvoided ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAvoided ? Icons.shield_rounded : Icons.warning_amber_rounded,
                        color: isAvoided ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('$channel • ${drill['timestamp']?.toString().split('T')[0] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAvoided ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAvoided ? 'Deflected' : 'Fallen',
                        style: TextStyle(
                          color: isAvoided ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Tab 2: Local Device Practice History ──────────────────────────────────
  Widget _buildLocalHistoryTab(String lang) {
    final box = Hive.isBoxOpen('simulation_results') ? Hive.box('simulation_results') : null;
    if (box == null) {
      return FutureBuilder(
        future: Hive.openBox('simulation_results'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return _buildLocalDashboardContent(Hive.box('simulation_results'), lang);
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    }
    return ValueListenableBuilder<Box>(
      valueListenable: box.listenable(),
      builder: (context, currentBox, _) => _buildLocalDashboardContent(currentBox, lang),
    );
  }

  Widget _buildLocalDashboardContent(Box box, String lang) {
    final items = <SimulationResult>[];
    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item is SimulationResult) {
        items.add(item);
      } else if (item is Map) {
        items.add(SimulationResult.fromMap(item));
      }
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final totalFaced = items.length;
    final avoidedCount = items.where((r) => r.isAvoided).length;
    final compromisedCount = items.where((r) => r.isCompromised).length;
    final scoreRate = totalFaced > 0 ? ((avoidedCount / totalFaced) * 100).round() : 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(UiStrings.get(lang, 'safety_scorecard'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(UiStrings.get(lang, 'family_guardian'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AnimatedScoreRing(score: scoreRate, lang: lang),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetricRow(label: UiStrings.get(lang, 'total_faced'), value: '$totalFaced', color: Colors.white),
                        const SizedBox(height: 12),
                        _buildMetricRow(label: UiStrings.get(lang, 'avoided'), value: '$avoidedCount', color: const Color(0xFF4ADE80)),
                        const SizedBox(height: 12),
                        _buildMetricRow(label: UiStrings.get(lang, 'fallen_for'), value: '$compromisedCount', color: const Color(0xFFF87171)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(UiStrings.get(lang, 'recent_history'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () => box.clear(),
                  child: Text(UiStrings.get(lang, 'clear_all'), style: const TextStyle(color: Colors.grey)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: const Center(child: Text('No local simulation drills recorded.')),
            )
          else
            ...items.map((result) {
              final isAvoided = result.isAvoided;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isAvoided ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAvoided ? Icons.shield_rounded : Icons.warning_amber_rounded,
                      color: isAvoided ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.scenarioTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('${_formatChannel(result.channel, lang)} • ${_formatDate(result.timestamp)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAvoided ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAvoided ? UiStrings.get(lang, 'avoided_badge') : UiStrings.get(lang, 'fallen_badge'),
                        style: TextStyle(
                          color: isAvoided ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetricRow({required String label, required String value, required Color color}) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
      ],
    );
  }
}

class _AnimatedScoreRing extends StatefulWidget {
  final int score;
  final String lang;
  const _AnimatedScoreRing({required this.score, required this.lang});

  @override
  State<_AnimatedScoreRing> createState() => _AnimatedScoreRingState();
}

class _AnimatedScoreRingState extends State<_AnimatedScoreRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _animation = Tween<double>(begin: 0.0, end: widget.score / 100.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.score / 100.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final currentPercent = (_animation.value * 100).round();
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _animation.value,
                strokeWidth: 10,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.score >= 80 ? const Color(0xFF4ADE80) : const Color(0xFFFACC15),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currentPercent%',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      UiStrings.get(widget.lang, 'score_badge'),
                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
