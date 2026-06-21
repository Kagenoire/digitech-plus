import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/course.dart';
import '../services/auth_service.dart';
import '../services/scraper_service.dart';
import '../services/sync_service.dart';
import '../widgets/presensi_card.dart';
import 'login_screen.dart';

class PresensiScreen extends StatefulWidget {
  const PresensiScreen({super.key});

  @override
  State<PresensiScreen> createState() => PresensiScreenState();
}

class PresensiScreenState extends State<PresensiScreen> {
  List<Course> _courses = [];
  final Map<String, CoursePresensiResult> _presensiData = {};
  bool _isLoading = false;
  bool _isLoadingPresensi = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() => _load();

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await AuthService.getSession();
      if (session == null) {
        _redirectToLogin();
        return;
      }
      final scraper = ScraperService(session);
      final courses = await scraper.fetchCourses();
      setState(() {
        _courses = courses;
        _isLoading = false;
      });

      // Save course IDs for background sync
      await SyncService.saveCourseIds(courses.map((c) => c.id).toList());

      // Load presensi per course
      setState(() => _isLoadingPresensi = true);
      for (final course in courses) {
        try {
          final result = await scraper.fetchPresensi(course.id);
          if (mounted) {
            setState(() => _presensiData[course.id] = result);
          }
        } on SessionExpiredException {
          _redirectToLogin();
          return;
        } catch (_) {
          continue;
        }
      }
    } on SessionExpiredException {
      _redirectToLogin();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingPresensi = false);
    }
  }

  void _redirectToLogin() {
    AuthService.clearSession();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          if (_isLoadingPresensi)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                color: AppTheme.primary,
                minHeight: 2,
              ),
            ),
          SliverToBoxAdapter(
            child: _openPresensiCount > 0
                ? Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active,
                            color: AppTheme.success, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$_openPresensiCount presensi sedang dibuka!',
                          style: const TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(height: 4),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final course = _courses[index];
                final presensi = _presensiData[course.id];
                return PresensiCourseCard(
                  course: course,
                  pertemuanList: presensi?.pertemuanList ?? [],
                  hasOpenToday: presensi?.hasOpenPresensiToday ?? false,
                );
              },
              childCount: _courses.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  int get _openPresensiCount =>
      _presensiData.values.where((r) => r.hasOpenPresensiToday).length;
}
