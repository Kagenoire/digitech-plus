import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/constants.dart';
import '../models/assignment.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _settingsChannel = MethodChannel(AppConstants.notifSettingsChannel);
  static bool _tzInitialized = false;

  // Regular notifications for new assignments
  static const _syncDetails = AndroidNotificationDetails(
    AppConstants.notifChannelId,
    AppConstants.notifChannelName,
    channelDescription: AppConstants.notifChannelDesc,
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  // Alarm-style: deadline reminders & tugas terlewat, bunyi meski silent
  static const _deadlineDetails = AndroidNotificationDetails(
    AppConstants.deadlineChannelId,
    AppConstants.deadlineChannelName,
    channelDescription: AppConstants.deadlineChannelDesc,
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  // Alarm-style: presensi dibuka, channel terpisah dari deadline agar
  // suara/gaya bisa diatur sendiri per kategori dari pengaturan HP.
  static const _presensiDetails = AndroidNotificationDetails(
    AppConstants.presensiChannelId,
    AppConstants.presensiChannelName,
    channelDescription: AppConstants.presensiChannelDesc,
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  static Future<void> initialize() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initSettings);
    await _createChannels();
    _initTimezone();
  }

  // Android only creates a channel the first time a notification using it
  // is shown. Creating them upfront means they already exist in the
  // system's per-app notification settings, so the user can customize sound
  // and vibration per category even before the first notification fires.
  static Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      AppConstants.notifChannelId,
      AppConstants.notifChannelName,
      description: AppConstants.notifChannelDesc,
      importance: Importance.high,
      playSound: true,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      AppConstants.deadlineChannelId,
      AppConstants.deadlineChannelName,
      description: AppConstants.deadlineChannelDesc,
      importance: Importance.max,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      AppConstants.presensiChannelId,
      AppConstants.presensiChannelName,
      description: AppConstants.presensiChannelDesc,
      importance: Importance.max,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
  }

  static void _initTimezone() {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    _tzInitialized = true;
  }

  /// Requests notification + exact-alarm permission. Returns true if the
  /// notification permission was granted (exact-alarm result is best-effort
  /// since not every Android version prompts for it).
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    return granted ?? false;
  }

  /// Whether the OS currently allows this app to post notifications.
  /// Use this to detect a permission that was revoked after being granted.
  static Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  /// Opens the system's per-app notification settings screen, where the
  /// user can pick their own sound/vibration/style per channel.
  static Future<void> openAppNotificationSettings() async {
    try {
      await _settingsChannel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// Opens the system settings for one specific channel, so the user can
  /// pick a custom sound/vibration/style for just that category.
  static Future<void> openChannelSettings(String channelId) async {
    try {
      await _settingsChannel.invokeMethod('openChannelSettings', {
        'channelId': channelId,
      });
    } catch (_) {}
  }

  // ── Immediate notifications ──────────────────────────────────────────────

  static Future<void> showNewAssignment(
    String assignmentTitle,
    String course,
  ) async {
    await _plugin.show(
      _id(assignmentTitle, 0),
      'Tugas baru: $assignmentTitle',
      course,
      const NotificationDetails(android: _syncDetails),
    );
  }

  static Future<void> showMissed(
    String assignmentTitle,
    String course,
  ) async {
    await _plugin.show(
      _id(assignmentTitle, 999),
      'Tugas terlewat: $assignmentTitle',
      course,
      const NotificationDetails(android: _deadlineDetails),
    );
  }

  static Future<void> showPresensiOpen(
    String courseName,
    String pertemuanLabel,
  ) async {
    await _plugin.show(
      (courseName.hashCode.abs() + pertemuanLabel.hashCode.abs()) % 100000,
      'Presensi dibuka!',
      '$pertemuanLabel - $courseName',
      const NotificationDetails(android: _presensiDetails),
    );
  }

  static Future<void> showSessionExpired() async {
    await _plugin.show(
      99999,
      'Login Digitech+ diperlukan',
      'Sesi kamu sudah habis. Buka app untuk login ulang.',
      const NotificationDetails(android: _deadlineDetails),
    );
  }

  // ── Scheduled exact alarms ───────────────────────────────────────────────

  /// Schedule a deadline reminder [hoursBeforeDeadline] hours before due date.
  /// Returns true if successfully scheduled, false if the time has already passed.
  static Future<bool> scheduleDeadlineReminder(
    Assignment assignment,
    int hoursBeforeDeadline,
  ) async {
    if (assignment.dueDate == null) return false;
    _initTimezone();
    final fireAt = assignment.dueDate!.subtract(
      Duration(hours: hoursBeforeDeadline),
    );
    if (!fireAt.isAfter(DateTime.now())) return false;

    final title = hoursBeforeDeadline <= 3
        ? 'Deadline $hoursBeforeDeadline jam lagi!'
        : 'Deadline besok: ${assignment.title}';

    // Convert to UTC so the alarm fires at the correct absolute moment
    // regardless of timezone database resolution.
    try {
      await _plugin.zonedSchedule(
        _scheduleId(assignment.uniqueKey, hoursBeforeDeadline),
        title,
        '${assignment.title} - ${assignment.courseCode}',
        tz.TZDateTime.from(fireAt.toUtc(), tz.UTC),
        const NotificationDetails(android: _deadlineDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (_) {
      // Exact-alarm permission likely not granted on this device, skip,
      // the next sync cycle will retry instead of aborting the whole sync.
      return false;
    }
  }

  static Future<void> cancelDeadlineReminder(
    String uniqueKey,
    int hoursBeforeDeadline,
  ) async {
    await _plugin.cancel(_scheduleId(uniqueKey, hoursBeforeDeadline));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static int _id(String text, int salt) =>
      (text.hashCode.abs() + salt) % 0x7FFFFFFF;

  static int _scheduleId(String uniqueKey, int hours) =>
      (uniqueKey.hashCode.abs() + hours * 1000) % 0x7FFFFFFF;
}
