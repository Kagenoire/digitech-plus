import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<bool> hasSession() async {
    final session = await _storage.read(key: AppConstants.sessionKey);
    return session != null && session.isNotEmpty;
  }

  static Future<String?> getSession() async {
    return _storage.read(key: AppConstants.sessionKey);
  }

  static Future<void> saveSession(String session) async {
    await _storage.write(key: AppConstants.sessionKey, value: session);
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.sessionKey);
  }

  static Map<String, String> buildHeaders(String session) {
    return {
      'Cookie': 'ci_session=$session',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) Digitech+/1.0',
      'Accept': 'text/html,application/xhtml+xml,*/*;q=0.9',
      'Accept-Language': 'id-ID,id;q=0.9,en;q=0.8',
      'Referer': AppConstants.baseUrl,
    };
  }
}
