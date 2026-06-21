class Assignment {
  final String title;
  final String type;
  final String courseCode;
  final String courseName;
  final int courseSks;
  final String kelasType;
  final String kelasName;
  final String lecturerName;
  final String pertemuanLabel;
  final DateTime? dueDate;
  final AssignmentStatus status;
  final String? detailUrl;
  final String? assignmentId;

  const Assignment({
    required this.title,
    required this.type,
    required this.courseCode,
    required this.courseName,
    required this.courseSks,
    required this.kelasType,
    required this.kelasName,
    required this.lecturerName,
    required this.pertemuanLabel,
    required this.dueDate,
    required this.status,
    this.detailUrl,
    this.assignmentId,
  });

  String get uniqueKey => assignmentId ?? '${courseCode}_${title.hashCode}';

  Duration get timeUntilDue =>
      dueDate != null ? dueDate!.difference(DateTime.now()) : Duration.zero;

  bool get isDueSoon =>
      dueDate != null &&
      timeUntilDue.inMinutes > 0 &&
      timeUntilDue.inHours <= 24;

  bool get isDueVerySoon =>
      dueDate != null &&
      timeUntilDue.inMinutes > 0 &&
      timeUntilDue.inHours <= 3;

  String get courseDisplay => '$courseCode | $courseName | $courseSks SKS';
}

enum AssignmentStatus { todo, missed, submitted }
