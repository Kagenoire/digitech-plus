class Course {
  final String id;
  final String code;
  final String name;
  final int sks;
  final String kelasType;
  final String kelasName;
  final String schedule;
  final String lecturerName;
  final String prodi;
  final int studentCount;

  const Course({
    required this.id,
    required this.code,
    required this.name,
    required this.sks,
    required this.kelasType,
    required this.kelasName,
    required this.schedule,
    required this.lecturerName,
    required this.prodi,
    required this.studentCount,
  });

  String get displayName => '$code | $name | $sks SKS';
  String get detailUrl =>
      'https://elearning.digitechuniversity.ac.id/course/detail/$id';
}
