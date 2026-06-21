import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/course.dart';
import '../models/pertemuan.dart';
import '../core/theme.dart';

class PresensiCourseCard extends StatelessWidget {
  final Course course;
  final List<Pertemuan> pertemuanList;
  final bool hasOpenToday;

  const PresensiCourseCard({
    super.key,
    required this.course,
    required this.pertemuanList,
    required this.hasOpenToday,
  });

  Future<void> _openCourse() async {
    final uri = Uri.tryParse(course.detailUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final openPertemuan =
        pertemuanList.where((p) => p.isOpen).toList();

    return Card(
      child: InkWell(
        onTap: _openCourse,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: hasOpenToday ? AppTheme.success : Colors.grey[300]!,
                width: 4,
              ),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      course.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (hasOpenToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha:0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Presensi Dibuka',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${course.kelasType} | ${course.kelasName}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (course.schedule.isNotEmpty)
                Text(
                  course.schedule,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              const Divider(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    course.lecturerName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              if (openPertemuan.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...openPertemuan.map((p) => _OpenPertemuanBadge(pertemuan: p)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenPertemuanBadge extends StatelessWidget {
  final Pertemuan pertemuan;
  const _OpenPertemuanBadge({required this.pertemuan});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.success.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 14, color: AppTheme.success),
          const SizedBox(width: 6),
          Text(
            '${pertemuan.label}'
            '${pertemuan.timeRange.isNotEmpty ? " — ${pertemuan.timeRange}" : ""}',
            style: const TextStyle(
              color: AppTheme.success,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
