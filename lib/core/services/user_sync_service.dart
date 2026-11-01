import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class UserSyncService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  /// Returns the current user's saved 4-digit PIN if generated and stored in DB, otherwise null.
  static String? getSavedPin() {
    final box = Hive.isBoxOpen('preferences') ? Hive.box('preferences') : null;
    final pin = (box?.get('userPin', defaultValue: '') as String?)?.trim();
    return (pin != null && pin.isNotEmpty) ? pin : null;
  }

  /// Backward-compatible PIN accessor
  static String getOrCreatePin() {
    return getSavedPin() ?? '----';
  }

  /// Syncs senior user profile with the backend SQLite database.
  /// When [pin] is null, the backend database generates/assigns a random 4-digit PIN.
  /// Returns a Map with {'success': bool, 'pin': String?, 'user': Map<String, dynamic>?}.
  static Future<Map<String, dynamic>?> syncUserProfile({
    String? name,
    required String phone,
    String? pin,
    int? safetyScore,
    int? totalDrills,
    int? avoidedDrills,
  }) async {
    final box = Hive.isBoxOpen('preferences') ? Hive.box('preferences') : null;
    final userName = name ?? (box?.get('userName', defaultValue: 'दादा जी (Senior)') as String);
    final userPhone = phone.trim();

    if (userPhone.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': userPhone,
          'name': userName.trim(),
          if (pin != null && pin.trim().isNotEmpty) 'pin': pin.trim(),
          'safety_score': safetyScore ?? 100,
          'total_drills': totalDrills ?? 0,
          'avoided_drills': avoidedDrills ?? 0,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>?;
        final assignedPin = user?['pin']?.toString();

        if (box != null) {
          box.put('userPhone', userPhone);
          box.put('userName', userName.trim());
          if (assignedPin != null && assignedPin.isNotEmpty) {
            box.put('userPin', assignedPin);
          }
        }

        debugPrint('[UserSyncService] Profile synced successfully for $userPhone, PIN: $assignedPin');
        return {
          'success': true,
          'pin': assignedPin,
          'user': user,
        };
      }
    } catch (e) {
      debugPrint('[UserSyncService] Sync error: $e');
    }
    return null;
  }

  /// Synchronizes all past local simulation results stored in Hive to the backend SQLite DB.
  /// This ensures that all drills completed before registering the phone number appear on Family Connect.
  static Future<int> syncHistoricalDrills(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) return 0;

    try {
      final box = Hive.isBoxOpen('simulation_results')
          ? Hive.box('simulation_results')
          : await Hive.openBox('simulation_results');

      if (box.isEmpty) return 0;

      final drills = <Map<String, dynamic>>[];
      for (int i = 0; i < box.length; i++) {
        final dynamic item = box.getAt(i);
        if (item == null) continue;

        try {
          final title = (item.scenarioTitle ?? item['scenarioTitle'] ?? item['scenario_title'] ?? 'Simulation Drill').toString();
          final channel = (item.channel ?? item['channel'] ?? 'call').toString();
          final status = (item.status ?? item['status'] ?? 'deflected').toString();
          final ts = item.timestamp != null 
              ? (item.timestamp is DateTime ? (item.timestamp as DateTime).toIso8601String() : item.timestamp.toString())
              : (item['timestamp']?.toString() ?? DateTime.now().toIso8601String());

          drills.add({
            'scenario_title': title,
            'channel': channel,
            'status': status,
            'timestamp': ts,
          });
        } catch (_) {}
      }

      if (drills.isEmpty) return 0;

      final response = await http.post(
        Uri.parse('$baseUrl/api/drills/batch_sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_phone': cleanPhone,
          'drills': drills,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final count = (data['synced_count'] as num?)?.toInt() ?? drills.length;
        debugPrint('[UserSyncService] Synced $count historical drills for $cleanPhone');
        return count;
      }
    } catch (e) {
      debugPrint('[UserSyncService] Historical batch sync failed: $e');
    }
    return 0;
  }

  /// Logs a completed drill for this user to backend SQLite
  static Future<void> logDrillActivity({
    required String scenarioTitle,
    required String channel,
    required String status,
  }) async {
    final box = Hive.isBoxOpen('preferences') ? Hive.box('preferences') : null;
    final userPhone = (box?.get('userPhone', defaultValue: '') as String).trim();
    if (userPhone.isEmpty) return;
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/api/drills/record'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_phone': userPhone,
          'scenario_title': scenarioTitle,
          'channel': channel,
          'status': status,
        }),
      );
    } catch (e) {
      debugPrint('[UserSyncService] Drill log error: $e');
    }
  }

  /// Connects to a senior's account using their phone and PIN
  static Future<Map<String, dynamic>> authorizeFamilyConnect({
    required String seniorPhone,
    required String pin,
    String? familyName,
    String? familyPhone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/family/authorize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senior_phone': seniorPhone.trim(),
          'pin': pin.trim(),
          'family_name': familyName ?? 'Family Member',
          'family_phone': familyPhone ?? '',
        }),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'authorized': false,
        'message': 'Cannot reach backend server. Make sure the Sumati AI service is active.',
        'data': null,
      };
    }
  }

  /// Fetches senior's live status and drills from backend SQLite
  static Future<Map<String, dynamic>?> fetchSeniorStatus(String seniorPhone) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/family/senior_status?senior_phone=${Uri.encodeComponent(seniorPhone.trim())}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['found'] == true) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('[UserSyncService] Fetch senior status error: $e');
    }
    return null;
  }

  /// Fetches all user-reported scams from backend SQLite
  static Future<Map<String, dynamic>> fetchAllScamReports({int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/scam_reports?limit=$limit'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[UserSyncService] Fetch reports error: $e');
    }
    return {'total_reports': 0, 'reports': []};
  }
}

