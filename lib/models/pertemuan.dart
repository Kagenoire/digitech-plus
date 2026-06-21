class Pertemuan {
  final String courseId;
  final String courseName;
  final int number;
  final int session;
  final DateTime? date;
  final String timeRange;
  final PertemuanStatus status;

  const Pertemuan({
    required this.courseId,
    required this.courseName,
    required this.number,
    required this.session,
    this.date,
    required this.timeRange,
    required this.status,
  });

  String get label => 'Pertemuan $number Sesi $session';

  String get cacheKey => '${courseId}_${number}_$session';

  bool get isOpen => status == PertemuanStatus.open;
}

enum PertemuanStatus { open, closed }
