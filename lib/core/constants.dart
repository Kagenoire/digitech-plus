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

  // Regular channel — new assignment notifications
  static const String notifChannelId = 'digitech_sync';
  static const String notifChannelName = 'Tugas Baru';
  static const String notifChannelDesc = 'Notifikasi saat ada tugas baru';

  // Alarm channel — deadline & presensi, plays sound even in silent mode
  static const String alarmChannelId = 'digitech_alarm';
  static const String alarmChannelName = 'Deadline & Presensi';
  static const String alarmChannelDesc =
      'Pengingat deadline dan presensi — bunyi meski HP silent';

  static const String cookieChannel = 'com.digitech/cookies';

  static const String prefBatteryExemptionAsked = 'battery_exemption_asked';
}
