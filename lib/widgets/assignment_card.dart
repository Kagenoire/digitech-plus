import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/assignment.dart';
import '../core/theme.dart';

class AssignmentCard extends StatelessWidget {
  final Assignment assignment;

  const AssignmentCard({super.key, required this.assignment});

  Color get _borderColor {
    switch (assignment.status) {
      case AssignmentStatus.todo:
        return assignment.isDueVerySoon
            ? AppTheme.danger
            : assignment.isDueSoon
                ? AppTheme.warning
                : AppTheme.primary;
      case AssignmentStatus.missed:
        return AppTheme.danger;
      case AssignmentStatus.submitted:
        return AppTheme.success;
    }
  }

  String get _dueDateLabel {
    final d = assignment.dueDate;
    if (d == null) return 'Tanggal tidak tersedia';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month]} ${d.year}  $h:$m';
  }

  String get _timeLeftLabel {
    if (assignment.status == AssignmentStatus.missed) return 'Terlewat';
    if (assignment.status == AssignmentStatus.submitted) return 'Submitted';
    if (assignment.dueDate == null) return '-';
    final diff = assignment.timeUntilDue;
    if (diff.isNegative) return 'Terlewat';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lagi';
    if (diff.inHours < 24) return '${diff.inHours} jam lagi';
    return '${diff.inDays} hari lagi';
  }

  Color get _timeLeftColor {
    if (assignment.status != AssignmentStatus.todo) return Colors.grey;
    if (assignment.dueDate == null) return Colors.grey;
    final diff = assignment.timeUntilDue;
    if (diff.inHours <= 3) return AppTheme.danger;
    if (diff.inHours <= 24) return AppTheme.warning;
    return AppTheme.primary;
  }

  Future<void> _openUrl() async {
    final url = assignment.detailUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: assignment.detailUrl != null ? _openUrl : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: _borderColor, width: 4),
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
                      assignment.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TypeBadge(type: assignment.type),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                assignment.courseDisplay,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
              Text(
                '${assignment.kelasType} | ${assignment.kelasName}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const Divider(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      assignment.lecturerName,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (assignment.pertemuanLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.class_outlined, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      assignment.pertemuanLabel,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        _dueDateLabel,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _timeLeftColor.withValues(alpha:0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _timeLeftLabel,
                      style: TextStyle(
                        color: _timeLeftColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isExam = type == 'Exam';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: (isExam ? AppTheme.warning : AppTheme.primary).withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: isExam ? AppTheme.warning : AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
