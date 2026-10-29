import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/practice_tag.dart';
import '../../core/widgets/i_feel_worried_button.dart';
import '../../core/models/scenario.dart';
import '../../core/models/simulation_result.dart';

class MessagePracticeScreen extends StatefulWidget {
  final String channelType; // 'whatsapp' or 'sms'
  final Scenario? scenario;

  const MessagePracticeScreen({
    super.key, 
    this.channelType = 'whatsapp',
    this.scenario,
  });

  @override
  State<MessagePracticeScreen> createState() => _MessagePracticeScreenState();
}

class _MessagePracticeScreenState extends State<MessagePracticeScreen> {
  int _currentBeat = 0;

  final List<Map<String, dynamic>> _beats = [
    {
      "sample": "CONGRATULATIONS! You have won ₹25,00,000 in the KBC Lottery. Reply YES to claim your cash prize immediately.",
      "options": [
        {"text": "YES! How can I collect the prize?", "outcome": "continue"},
        {"text": "I never participated in any lottery. Delete.", "outcome": "success:ignored"},
      ]
    },
    {
      "sample": "Sir, this is 100% genuine government approved. Please send ₹500 processing fee via UPI to claim.",
      "options": [
        {"text": "Okay, sending the ₹500 now.", "outcome": "failure:sent_money"},
        {"text": "No lottery asks for advance fees. Goodbye.", "outcome": "success:refused"},
      ]
    }
  ];

  void _handleOptionSelection(String outcome) {
    if (outcome == 'continue') {
      if (_currentBeat < _beats.length - 1) {
        setState(() => _currentBeat++);
      } else {
        SimulationResult.recordResult(
          scenarioTitle: widget.scenario?.title ?? 'Message Scenario',
          channel: widget.channelType,
          status: 'deflected',
        );
        context.replace('/debrief', extra: {
          'outcome': 'success:survived',
          'message': widget.scenario?.debriefSuccess ?? 'Great job avoiding the scam!'
        });
      }
    } else {
      final isSuccess = outcome.startsWith('success');
      SimulationResult.recordResult(
        scenarioTitle: widget.scenario?.title ?? 'Message Scenario',
        channel: widget.channelType,
        status: isSuccess ? 'deflected' : 'compromised',
      );
      context.replace('/debrief', extra: {
        'outcome': outcome,
        'message': isSuccess 
            ? (widget.scenario?.debriefSuccess ?? 'Safe choice!') 
            : (widget.scenario?.debriefFailure ?? 'Scammers use links to steal your data.')
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWhatsApp = widget.channelType == 'whatsapp';
    final currentBeatData = _beats[_currentBeat];
    final options = currentBeatData['options'] as List<Map<String, String>>;

    return Scaffold(
      appBar: AppBar(
        title: Text(isWhatsApp ? 'WhatsApp Alert' : 'SMS Alert'),
        backgroundColor: isWhatsApp ? const Color(0xFF075E54) : Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const PracticeTag(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isWhatsApp ? const Color(0xFFDCF8C6) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        currentBeatData['sample'] as String,
                        style: const TextStyle(fontSize: 18, color: Colors.black87),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text('How will you respond?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...options.map((opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ElevatedButton(
                      onPressed: () => _handleOptionSelection(opt['outcome']!),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: Text(opt['text']!, textAlign: TextAlign.center),
                    ),
                  )),
                  const SizedBox(height: 16),
                  const IFeelWorriedButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
