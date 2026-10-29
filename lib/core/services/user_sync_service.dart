import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class UserSyncService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  /// Returns the current user's 4-digit PIN, generating one if not set
  static String getOrCreatePin() {
    final box = Hive.isBoxOpen('preferences') ? Hive.box('preferences') : null;
    if (box == null) return '1234';

    var pin = box.get('userPin', defaultValue: '') as String;
    if (pin.trim().isEmpty) {
      final random = Random();
      pin = (1000 + random.nextInt(9000)).toString();
      box.put('userPin', pin);
    }
    return pin;
  }

  /// Syncs senior user profile with the backend SQLite database
  static Future<bool> syncUserProfile({
    String? name,
    String? phone,
    String? pin,
    int? safetyScore,
    int? totalDrills,
    int? avoidedDrills,
  }) async {
    final box = Hive.isBoxOpen('preferences') ? Hive.box('preferences') : null;
    final userName = name ?? (box?.get('userName', defaultValue: 'दादा जी (Senior)') as String);
    final userPhone = phone ?? (box?.get('userPhone', defaultValue: '') as String);
    final userPin = pin ?? getOrCreatePin();

    if (userPhone.trim().isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': userPhone.trim(),
          'name': userName.trim(),
          'pin': userPin.trim(),
          'safety_score': safetyScore ?? 100,
          'total_drills': totalDrills ?? 0,
          'avoided_drills': avoidedDrills ?? 0,
        }),
      );
      if (response.statusCode == 200) {
        debugPrint('[UserSyncService] Profile synced successfully for $userPhone');
        return true;
      }
    } catch (e) {
      debugPrint('[UserSyncService] Sync error: $e');
    }
    return false;
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

