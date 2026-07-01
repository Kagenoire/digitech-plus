import 'package:flutter/services.dart';

/// Bridges to the native full-screen alarm activity that rings until the
/// user slides to dismiss it, then routes back into the app.
class AlarmService {
  static const _channel = MethodChannel('com.digitech/alarm');

  static Future<void> ringNow({
    required String type,
    required String title,
    required String body,
    required String channelId,
  }) async {
    try {
      await _channel.invokeMethod('ringNow', {
        'type': type,
        'title': title,
        'body': body,
        'channelId': channelId,
      });
    } catch (_) {}
  }
}
