import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/practice_tag.dart';
import '../../core/utils/simulation_trigger.dart';
import '../../core/models/scenario.dart';

class FakeAndroidScreen extends StatefulWidget {
  final Scenario? scenario;
  final String title;
  final String persona;
  final String initialMsg;
  final String channel;

  const FakeAndroidScreen({
    super.key,
    this.scenario,
    this.title = 'Unknown Number',
    this.persona = 'a scammer attempting fraud',
    this.initialMsg = 'Hello. Please respond urgently.',
    this.channel = 'whatsapp',
  });

  @override
  State<FakeAndroidScreen> createState() => _FakeAndroidScreenState();
}

class _FakeAndroidScreenState extends State<FakeAndroidScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Simulate realistic heads-up notification sliding from top after 1.8 seconds
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        SimulationTrigger.startSimulation(context, widget.scenario);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    SimulationTrigger.cancelActiveSimulation();
    super.dispose();
  }

  void _openDirectPractice(String targetChannel) {
    _timer?.cancel();
    SimulationTrigger.cancelActiveSimulation();
    if (targetChannel == 'web') {
      context.replace('/practice/web', extra: widget.scenario);
    } else if (targetChannel == 'call') {
      context.replace('/practice/call', extra: {'scenario': widget.scenario, 'startActive': true});
    } else {
      context.push('/ai_chat', extra: {
        'persona': widget.persona,
        'initialMessage': widget.initialMsg,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const PracticeTag(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8ECAE6), Color(0xFF219EBC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildFakeStatusBar(),
                    const SizedBox(height: 32),
                    _buildFakeAppGrid(),
                    const Spacer(),
                    _buildFakeDock(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFakeStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: const [
          Text('14:30', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Spacer(),
          Icon(Icons.wifi, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Icon(Icons.battery_full, color: Colors.white, size: 16),
        ],
      ),
    );
  }

  Widget _buildFakeAppGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 24,
        crossAxisSpacing: 16,
        children: [
          _AppIcon(icon: Icons.map, label: 'Maps', color: Colors.green.shade400),
          _AppIcon(icon: Icons.camera_alt, label: 'Camera', color: Colors.grey.shade800),
          _AppIcon(icon: Icons.photo, label: 'Photos', color: Colors.purple.shade400),
          _AppIcon(icon: Icons.settings, label: 'Settings', color: Colors.blueGrey.shade600),
          _AppIcon(icon: Icons.play_arrow, label: 'Videos', color: Colors.red.shade400),
          _AppIcon(icon: Icons.email, label: 'Mail', color: Colors.blue.shade400),
          _AppIcon(icon: Icons.calculate, label: 'Calc', color: Colors.orange.shade400),
          _AppIcon(icon: Icons.calendar_month, label: 'Calendar', color: Colors.indigo.shade400),
        ],
      ),
    );
  }

  Widget _buildFakeDock() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _openDirectPractice('call'),
            child: _AppIcon(icon: Icons.phone, label: '', color: Colors.green.shade500),
          ),
          GestureDetector(
            onTap: () => _openDirectPractice('sms'),
            child: _AppIcon(icon: Icons.message, label: '', color: Colors.blue.shade500),
          ),
          GestureDetector(
            onTap: () => _openDirectPractice('web'),
            child: _AppIcon(icon: Icons.public, label: '', color: Colors.red.shade500),
          ),
          GestureDetector(
            onTap: () => _openDirectPractice('whatsapp'),
            child: _AppIcon(icon: Icons.chat, label: '', color: Colors.green.shade600),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AppIcon({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ],
    );
  }
}
