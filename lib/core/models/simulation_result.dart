import 'package:hive_flutter/hive_flutter.dart';
import '../services/user_sync_service.dart';

@HiveType(typeId: 1)
class SimulationResult extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String scenarioTitle;

  @HiveField(2)
  final String channel;

  @HiveField(3)
  final String status;

  @HiveField(4)
  final DateTime timestamp;

  SimulationResult({
    required this.id,
    required this.scenarioTitle,
    required this.channel,
    required this.status,
    required this.timestamp,
  });

  bool get isAvoided =>
      status == 'deflected' ||
      status == 'success:hung_up' ||
      status.startsWith('success');

  bool get isCompromised =>
      status == 'compromised' || status.startsWith('failure');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scenarioTitle': scenarioTitle,
      'channel': channel,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SimulationResult.fromMap(Map<dynamic, dynamic> map) {
    return SimulationResult(
      id: map['id']?.toString() ?? '',
      scenarioTitle: map['scenarioTitle']?.toString() ?? 'Simulation',
      channel: map['channel']?.toString() ?? 'call',
      status: map['status']?.toString() ?? 'deflected',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static Future<void> recordResult({
    required String scenarioTitle,
    required String channel,
    required String status,
    String? id,
  }) async {
    try {
      final box = Hive.isBoxOpen('simulation_results')
          ? Hive.box('simulation_results')
          : await Hive.openBox('simulation_results');

      final result = SimulationResult(
        id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        scenarioTitle: scenarioTitle,
        channel: channel,
        status: status,
        timestamp: DateTime.now(),
      );

      await box.add(result);

      // Also sync drill activity to backend SQLite database
      UserSyncService.logDrillActivity(
        scenarioTitle: scenarioTitle,
        channel: channel,
        status: status,
      );
    } catch (_) {}
  }
}

class SimulationResultAdapter extends TypeAdapter<SimulationResult> {
  @override
  final int typeId = 1;

  @override
  SimulationResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SimulationResult(
      id: fields[0] as String? ?? '',
      scenarioTitle: fields[1] as String? ?? 'Simulation',
      channel: fields[2] as String? ?? 'call',
      status: fields[3] as String? ?? 'deflected',
      timestamp: fields[4] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, SimulationResult obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.scenarioTitle)
      ..writeByte(2)
      ..write(obj.channel)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimulationResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
