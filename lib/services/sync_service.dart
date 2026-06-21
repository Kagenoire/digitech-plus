import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../core/constants.dart';
import '../models/assignment.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'scraper_service.dart';

class SyncService {
  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      AppConstants.syncTaskName,
      AppConstants.syncTaskTag,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancelSync() async {
    await Workmanager().cancelByUniqueName(AppConstants.syncTaskName);
  }

  /// Called from background isolate (WorkManager callback).
  static Future<void> runBackgroundSync() async {
    WidgetsFlutterBinding.ensureInitialized();
    await NotificationService.initialize();
    try {
      await _doSync();
      // Clear session-expired flag on successful sync
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.prefSessionExpiredShown);
    } on SessionExpiredException {
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool(AppConstants.prefSessionExpiredShown) ?? false;
      if (!alreadyShown) {
        await NotificationService.showSessionExpired();
        await prefs.setBool(AppConstants.prefSessionExpiredShown, true);
      }
    } catch (_) {
      // Network/parse error — try again next cycle
    }
  }

  /// Called from foreground (binding and notifications already initialized).
  static Future<void> syncNow({bool resetSeen = false}) async {
    if (resetSeen) await clearSeenState();
    await _doSync();
  }

  static Future<void> _doSync() async {
    final session = await AuthService.getSession();
    if (session == null) return;

    final scraper = ScraperService(session);
    final prefs = await SharedPreferences.getInstance();

    await _syncTodo(scraper, prefs);
    await _syncPresensi(scraper, prefs);

    await prefs.setString(
      AppConstants.prefLastSync,
      DateTime.now().toIso8601String(),
    );
  }

  static Future<void> _syncTodo(
    ScraperService scraper,
    SharedPreferences prefs,
  ) async {
    final todoMap = await scraper.fetchTodo();

    final seenIds = Set<String>.from(
      jsonDecode(prefs.getString(AppConstants.prefSeenIds) ?? '[]') as List,
    );
    final missedIds = Set<String>.from(
      jsonDecode(prefs.getString(AppConstants.prefMissedIds) ?? '[]') as List,
    );
    final scheduled24h = Set<String>.from(
      jsonDecode(prefs.getString(AppConstants.prefScheduled24h) ?? '[]') as List,
    );
    final scheduled3h = Set<String>.from(
      jsonDecode(prefs.getString(AppConstants.prefScheduled3h) ?? '[]') as List,
    );

    final todoItems = todoMap[AssignmentStatus.todo] ?? [];
    final missedItems = todoMap[AssignmentStatus.missed] ?? [];

    for (final a in todoItems) {
      final key = a.uniqueKey;

      // Immediate notification for newly seen assignments
      if (!seenIds.contains(key)) {
        seenIds.add(key);
        await NotificationService.showNewAssignment(a.title, a.courseCode);
      }

      // Schedule exact H-24 alarm (only once per assignment)
      if (!scheduled24h.contains(key)) {
        final ok = await NotificationService.scheduleDeadlineReminder(a, 24);
        if (ok) scheduled24h.add(key);
      }

      // Schedule exact H-3 alarm (only once per assignment)
      if (!scheduled3h.contains(key)) {
        final ok = await NotificationService.scheduleDeadlineReminder(a, 3);
        if (ok) scheduled3h.add(key);
      }
    }

    // Cancel pending alarms for assignments that are now missed/submitted
    for (final a in missedItems) {
      final key = a.uniqueKey;

      if (!missedIds.contains(key)) {
        missedIds.add(key);
        await NotificationService.showMissed(a.title, a.courseCode);
      }

      if (scheduled24h.remove(key)) {
        await NotificationService.cancelDeadlineReminder(key, 24);
      }
      if (scheduled3h.remove(key)) {
        await NotificationService.cancelDeadlineReminder(key, 3);
      }
    }

    await prefs.setString(AppConstants.prefSeenIds, jsonEncode(seenIds.toList()));
    await prefs.setString(AppConstants.prefMissedIds, jsonEncode(missedIds.toList()));
    await prefs.setString(AppConstants.prefScheduled24h, jsonEncode(scheduled24h.toList()));
    await prefs.setString(AppConstants.prefScheduled3h, jsonEncode(scheduled3h.toList()));
  }

  static Future<void> _syncPresensi(
    ScraperService scraper,
    SharedPreferences prefs,
  ) async {
    final cachedIdsJson = prefs.getString(AppConstants.prefCourseIds);
    if (cachedIdsJson == null) return;

    final courseIds = List<String>.from(jsonDecode(cachedIdsJson) as List);
    final statusMap = Map<String, String>.from(
      jsonDecode(prefs.getString(AppConstants.prefPresensiStatus) ?? '{}') as Map,
    );

    for (final courseId in courseIds) {
      try {
        final result = await scraper.fetchPresensi(courseId);

        for (final pertemuan in result.pertemuanList) {
          final key = pertemuan.cacheKey;
          final prevStatus = statusMap[key] ?? 'closed';
          final newStatus = pertemuan.isOpen ? 'open' : 'closed';

          if (prevStatus == 'closed' && newStatus == 'open') {
            await NotificationService.showPresensiOpen(
              result.courseName,
              pertemuan.label,
            );
          }

          statusMap[key] = newStatus;
        }
      } catch (_) {
        continue;
      }
    }

    await prefs.setString(
      AppConstants.prefPresensiStatus,
      jsonEncode(statusMap),
    );
  }

  /// Clears all change-detection state so the next sync fires notifications
  /// for all current data (useful for testing).
  static Future<void> clearSeenState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefSeenIds);
    await prefs.remove(AppConstants.prefMissedIds);
    await prefs.remove(AppConstants.prefScheduled24h);
    await prefs.remove(AppConstants.prefScheduled3h);
    await prefs.remove(AppConstants.prefPresensiStatus);
  }

  /// Save course IDs to prefs so background sync can use them.
  static Future<void> saveCourseIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefCourseIds, jsonEncode(ids));
  }

  static Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.prefLastSync);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
