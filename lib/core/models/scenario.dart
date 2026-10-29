class Scenario {
  final String id;
  final String language;
  final String title;
  final String channel;
  final String difficulty;
  final String debriefSuccess;
  final String debriefFailure;
  final String? goal;
  final String? persona;
  final String? scammerName;
  final String? initialMessage;
  final Map<String, dynamic>? webPage;

  Scenario({
    required this.id,
    required this.language,
    required this.title,
    required this.channel,
    required this.difficulty,
    required this.debriefSuccess,
    required this.debriefFailure,
    this.goal,
    this.persona,
    this.scammerName,
    this.initialMessage,
    this.webPage,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) {
    String? personaStr;
    String? scammerNameStr;
    if (json['scammer_persona'] is Map) {
      final p = json['scammer_persona'] as Map<String, dynamic>;
      scammerNameStr = p['name']?.toString();
      final inst = p['institution']?.toString() ?? '';
      final style = p['voice_style']?.toString() ?? '';
      personaStr = "${scammerNameStr ?? 'A scammer'} from $inst with a $style tone";
    } else if (json['persona'] != null) {
      personaStr = json['persona'].toString();
    }

    String? initialMsg = json['initial_message']?.toString();
    if (initialMsg == null && json['script_skeleton'] is List && (json['script_skeleton'] as List).isNotEmpty) {
      final firstBeat = (json['script_skeleton'] as List).first;
      if (firstBeat is Map && firstBeat['sample'] != null) {
        initialMsg = firstBeat['sample'].toString();
      }
    }

    return Scenario(
      id: json['id'] ?? '',
      language: json['language'] ?? 'en',
      title: json['title'] ?? 'Unknown',
      channel: json['channel'] ?? 'unknown',
      difficulty: json['difficulty'] ?? 'easy',
      debriefSuccess: json['debrief_success'] ?? '',
      debriefFailure: json['debrief_failure'] ?? '',
      goal: json['goal']?.toString(),
      persona: personaStr,
      scammerName: scammerNameStr,
      initialMessage: initialMsg,
      webPage: json['web_page'] is Map ? json['web_page'] as Map<String, dynamic> : null,
    );
  }
}
