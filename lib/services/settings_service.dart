import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyName = 'gemini_api_key';

  Future<void> saveApiKey(String key) async {
    await _storage.write(key: _keyName, value: key.trim());
  }

  Future<String?> getApiKey() async {
    final key = await _storage.read(key: _keyName);
    if (key != null && key.trim().isNotEmpty) {
      return key.trim();
    }
    return null;
  }

  Future<void> deleteApiKey() async {
    await _storage.delete(key: _keyName);
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }
}
