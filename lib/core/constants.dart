class AppConstants {
  static const String baseUrl = 'https://elearning.digitechuniversity.ac.id';
  static const String todoUrl = '$baseUrl/course/todo_student';
  static const String courseListUrl = '$baseUrl/course';
  static const String courseDetailUrl = '$baseUrl/course/detail';

  static const String sessionKey = 'ci_session';
  static const String tahunIdFallback = '11';
  static const String prefDetectedTahunId = 'detected_tahun_id';

  static const String syncTaskName = 'digitech_bg_sync';
  static const String syncTaskTag = 'sync';

  static const String prefSessionExpiredShown = 'session_expired_shown';

  static const String prefSeenIds = 'seen_assignment_ids';
  static const String prefMissedIds = 'seen_missed_ids';
  static const String prefScheduled24h = 'scheduled_24h_ids';
  static const String prefScheduled3h = 'scheduled_3h_ids';
  static const String prefPresensiStatus = 'presensi_status';
  static const String prefLastSync = 'last_sync_time';
  static const String prefCourseIds = 'cached_course_ids';

  static const String prefNotifTugasEnabled = 'notif_tugas_enabled';
  static const String prefNotifPresensiEnabled = 'notif_presensi_enabled';

  // Regular channel: new assignment notifications
  static const String notifChannelId = 'digitech_sync';
  static const String notifChannelName = 'Tugas Baru';
  static const String notifChannelDesc = 'Notifikasi saat ada tugas baru';

  // Alarm-style channel: deadline reminders & tugas terlewat, tugas group
  static const String deadlineChannelId = 'digitech_deadline_tugas';
  static const String deadlineChannelName = 'Deadline & Tugas';
  static const String deadlineChannelDesc =
      'Pengingat deadline dan tugas terlewat, bunyi meski HP silent';

  // Alarm-style channel: presensi dibuka, terpisah agar suara bisa diatur sendiri
  static const String presensiChannelId = 'digitech_presensi';
  static const String presensiChannelName = 'Presensi';
  static const String presensiChannelDesc =
      'Notifikasi saat presensi mata kuliah dibuka, bunyi meski HP silent';

  static const String cookieChannel = 'com.digitech/cookies';
  static const String notifSettingsChannel = 'com.digitech/notifications';

  static const String prefBatteryExemptionAsked = 'battery_exemption_asked';
}
