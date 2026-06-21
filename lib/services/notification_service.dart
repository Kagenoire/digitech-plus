import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/constants.dart';
import '../models/assignment.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
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

  // Alarm-style: plays sound even in silent/vibrate mode
  static const _alarmDetails = AndroidNotificationDetails(
    AppConstants.alarmChannelId,
    AppConstants.alarmChannelName,
    channelDescription: AppConstants.alarmChannelDesc,
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
    _initTimezone();
  }

  static void _initTimezone() {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    _tzInitialized = true;
  }

  static Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
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
      const NotificationDetails(android: _alarmDetails),
    );
  }

  static Future<void> showPresensiOpen(
    String courseName,
    String pertemuanLabel,
  ) async {
    await _plugin.show(
      (courseName.hashCode.abs() + pertemuanLabel.hashCode.abs()) % 100000,
      'Presensi dibuka!',
      '$pertemuanLabel — $courseName',
      const NotificationDetails(android: _alarmDetails),
    );
  }

  static Future<void> showSessionExpired() async {
    await _plugin.show(
      99999,
      'Login Digitech+ diperlukan',
      'Sesi kamu sudah habis. Buka app untuk login ulang.',
      const NotificationDetails(android: _alarmDetails),
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
    await _plugin.zonedSchedule(
      _scheduleId(assignment.uniqueKey, hoursBeforeDeadline),
      title,
      '${assignment.title} — ${assignment.courseCode}',
      tz.TZDateTime.from(fireAt.toUtc(), tz.UTC),
      const NotificationDetails(android: _alarmDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return true;
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
