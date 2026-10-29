import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

class StorageService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _encryptionKeyId = 'sumati_hive_key';
  
  static Future<void> init() async {
    await Hive.initFlutter();

    // 1. Open userSettingsBox
    await Hive.openBox('userSettingsBox'); 

    // 2. Retrieve or generate the AES encryption key for secureDataBox
    try {
      String? encryptionKeyString = await _secureStorage.read(key: _encryptionKeyId);
      if (encryptionKeyString == null) {
        final List<int> key = Hive.generateSecureKey();
        encryptionKeyString = base64UrlEncode(key);
        await _secureStorage.write(key: _encryptionKeyId, value: encryptionKeyString);
      }
      
      final Uint8List encryptionKey = base64Url.decode(encryptionKeyString);
      final cipher = HiveAesCipher(encryptionKey);
      await Hive.openBox('secureDataBox', encryptionCipher: cipher); 
    } catch (e) {
      debugPrint('Warning: secureDataBox fallback without cipher: $e');
      if (!Hive.isBoxOpen('secureDataBox')) {
        await Hive.openBox('secureDataBox');
      }
    }
  }
}
