import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/assignment.dart';
import '../models/course.dart';
import '../models/pertemuan.dart';
import '../core/constants.dart';
import 'auth_service.dart';

class SessionExpiredException implements Exception {
  @override
  String toString() => 'Sesi telah berakhir. Silakan login kembali.';
}

class ScraperService {
  final String _session;

  ScraperService(this._session);

  Map<String, String> get _headers => AuthService.buildHeaders(_session);

  bool _isLoginPage(String body) {
    return body.contains('name="npm"') ||
        body.contains('name="password"') ||
        (body.contains('Login') && body.contains('Password') && body.length < 8000);
  }

  // --- TAHUN ID AUTO-DETECT ---

  Future<String> _getOrDetectTahunId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(AppConstants.prefDetectedTahunId);
    if (cached != null) return cached;

    final detected = await _detectTahunId();
    await prefs.setString(AppConstants.prefDetectedTahunId, detected);
    return detected;
  }

  Future<String> _detectTahunId() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/course/todo'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (_isLoginPage(response.body)) return AppConstants.tahunIdFallback;

      final doc = html_parser.parse(response.body);

      // Cari select dropdown bertanda "tahun"
      for (final select in doc.querySelectorAll('select')) {
        final name = (select.attributes['name'] ?? '').toLowerCase();
        final id = select.id.toLowerCase();
        if (name.contains('tahun') || id.contains('tahun')) {
          final selected = select.querySelector('option[selected]')
              ?? select.querySelector('option');
          final val = selected?.attributes['value'];
          if (val != null && val.isNotEmpty) return val;
        }
      }

      // Fallback: cari di hidden input atau data attribute
      final hiddenInput = doc.querySelector(
        'input[name*="tahun"], input[id*="tahun"]',
      );
      final val = hiddenInput?.attributes['value'];
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}

    return AppConstants.tahunIdFallback;
  }

  // --- TODO / ASSIGNMENTS ---

  Future<Map<AssignmentStatus, List<Assignment>>> fetchTodo() async {
    final tahunId = await _getOrDetectTahunId();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(AppConstants.todoUrl),
    )
      ..headers.addAll(_headers)
      ..fields['tahun_id'] = tahunId
      ..fields['course_id'] = '';

    final streamed = await request.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);

    if (_isLoginPage(response.body)) throw SessionExpiredException();
    if (response.statusCode != 200) {
      throw Exception('Gagal mengambil data tugas (${response.statusCode})');
    }

    return _parseTodoHtml(response.body);
  }

  Map<AssignmentStatus, List<Assignment>> _parseTodoHtml(String html) {
    final doc = html_parser.parse(html);
    return {
      AssignmentStatus.todo: _parseSection(doc, '#todo', AssignmentStatus.todo),
      AssignmentStatus.missed: _parseSection(doc, '#missed', AssignmentStatus.missed),
      AssignmentStatus.submitted: _parseSection(doc, '#submitted', AssignmentStatus.submitted),
    };
  }

  List<Assignment> _parseSection(
    dom.Document doc,
    String selector,
    AssignmentStatus status,
  ) {
    final section = doc.querySelector(selector);
    if (section == null) return [];

    final cards = section.querySelectorAll('.card');
    final result = <Assignment>[];
    for (final card in cards) {
      try {
        final a = _parseCard(card, status);
        if (a != null) result.add(a);
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  Assignment? _parseCard(dom.Element card, AssignmentStatus status) {
    final titleAnchor = card.querySelector('h4 a');
    final titleEl = card.querySelector('h4');
    if (titleEl == null) return null;

    final title = _cleanText(titleAnchor?.text ?? titleEl.text);
    if (title.isEmpty) return null;

    final detailUrl = titleAnchor?.attributes['href'];
    String? assignmentId;
    if (detailUrl != null) {
      final m = RegExp(r'/classwork/(\d+)').firstMatch(detailUrl);
      assignmentId = m?.group(1);
    }

    final typeBadge = card.querySelector('.badge-soft-danger, .badge');
    final typeText = _cleanText(typeBadge?.text ?? '');
    final type = typeText.contains('Exam') ? 'Exam' : 'Assignment';

    final courseEl = card.querySelector('p.text-muted.font-size-15, p.font-size-15');
    final kelasEl = card.querySelector('p.text-muted.font-size-13, p.font-size-13');

    final courseParts = _cleanText(courseEl?.text ?? '').split('|');
    final courseCode = courseParts.isNotEmpty ? courseParts[0].trim() : '';
    final courseName = courseParts.length > 1 ? courseParts[1].trim() : '';
    final courseSks = courseParts.length > 2 ? int.tryParse(courseParts[2].trim()) ?? 0 : 0;

    final kelasParts = _cleanText(kelasEl?.text ?? '').split('|');
    final kelasType = kelasParts.isNotEmpty ? kelasParts[0].trim() : '';
    final kelasName = kelasParts.length > 1 ? kelasParts[1].trim() : '';

    final lecturerEl = card.querySelector('h6');
    final lecturerName = _cleanText(lecturerEl?.text ?? '');

    final infoPs = card.querySelectorAll('p.font-size-14');
    final pertemuanLabel = infoPs.isNotEmpty ? _cleanText(infoPs[0].text) : '';

    final dueDate = _findDueDate(card);

    return Assignment(
      title: title,
      type: type,
      courseCode: courseCode,
      courseName: courseName,
      courseSks: courseSks,
      kelasType: kelasType,
      kelasName: kelasName,
      lecturerName: lecturerName,
      pertemuanLabel: pertemuanLabel,
      dueDate: dueDate,
      status: status,
      detailUrl: detailUrl,
      assignmentId: assignmentId,
    );
  }

  DateTime? _findDueDate(dom.Element card) {
    final h5Elements = card.querySelectorAll('h5');
    for (final h5 in h5Elements) {
      if (h5.text.contains('Due Date')) {
        final parent = h5.parent;
        final p = parent?.querySelector('p');
        if (p != null) return _parseDueDateParagraph(p);
      }
    }
    return null;
  }

  DateTime? _parseDueDateParagraph(dom.Element p) {
    // Extract text nodes only (skip <i> icon nodes and <br> elements)
    final textParts = p.nodes
        .where((n) => n.nodeType == dom.Node.TEXT_NODE)
        .map((n) => (n.text ?? '').trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (textParts.length < 2) {
      // Fallback: split full text by whitespace
      final full = _cleanText(p.text);
      final parts = full.split(RegExp(r'\s+'));
      if (parts.length >= 4) {
        return _parseIndonesianDate(
          '${parts[0]} ${parts[1]} ${parts[2]}',
          parts[3],
        );
      }
      return null;
    }

    return _parseIndonesianDate(textParts[0], textParts[1]);
  }

  DateTime? _parseIndonesianDate(String dateStr, String timeStr) {
    const months = {
      'Januari': 1, 'Februari': 2, 'Maret': 3, 'April': 4,
      'Mei': 5, 'Juni': 6, 'Juli': 7, 'Agustus': 8,
      'September': 9, 'Oktober': 10, 'November': 11, 'Desember': 12,
    };

    try {
      final parts = dateStr.trim().split(' ');
      if (parts.length != 3) return null;
      final day = int.parse(parts[0]);
      final month = months[parts[1]];
      if (month == null) return null;
      final year = int.parse(parts[2]);

      final timeParts = timeStr.trim().split(':');
      if (timeParts.length < 2) return null;
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  // --- COURSE LIST ---

  Future<List<Course>> fetchCourses() async {
    final response = await http.get(
      Uri.parse(AppConstants.courseListUrl),
      headers: _headers,
    ).timeout(const Duration(seconds: 20));

    if (_isLoginPage(response.body)) throw SessionExpiredException();
    if (response.statusCode != 200) {
      throw Exception('Gagal mengambil daftar mata kuliah');
    }

    return _parseCoursesHtml(response.body);
  }

  List<Course> _parseCoursesHtml(String html) {
    final doc = html_parser.parse(html);
    final courses = <Course>[];

    // Course cards link to /course/detail/{id}
    final links = doc.querySelectorAll('a[href*="/course/detail/"]');
    final seenIds = <String>{};

    for (final link in links) {
      try {
        final href = link.attributes['href'] ?? '';
        final m = RegExp(r'/course/detail/(\d+)').firstMatch(href);
        if (m == null) continue;
        final id = m.group(1)!;
        if (seenIds.contains(id)) continue;
        seenIds.add(id);

        // Walk up to find the card container
        dom.Element? card = link.parent;
        for (int i = 0; i < 5; i++) {
          if (card == null) break;
          if (card.classes.contains('card')) break;
          card = card.parent;
        }
        if (card == null) continue;

        final titleText = _cleanText(link.text);
        final parts = titleText.split('|');
        final code = parts.isNotEmpty ? parts[0].trim() : '';
        final name = parts.length > 1 ? parts[1].trim() : '';
        final sks = parts.length > 2 ? int.tryParse(parts[2].trim()) ?? 0 : 0;

        String kelasType = '', kelasName = '', schedule = '', prodi = '', lecturer = '';
        int studentCount = 0;

        for (final p in card.querySelectorAll('p')) {
          final text = _cleanText(p.text);
          if (text.contains('Reguler') && text.contains('Kelas')) {
            final kp = text.split('|');
            kelasType = kp.isNotEmpty ? kp[0].trim() : '';
            kelasName = kp.length > 1 ? kp[1].trim() : '';
          } else if (text.contains('s/d') || text.contains(':')) {
            schedule = text;
          } else if (text.contains('S1') || text.contains('S2') || text.contains('Informatika')) {
            prodi = text;
          }
        }

        for (final el in card.querySelectorAll('h6, .font-size-14')) {
          final text = _cleanText(el.text);
          if (text.isNotEmpty && !text.contains('Pertemuan') && !text.contains('s/d')) {
            lecturer = text;
          }
        }

        for (final el in card.querySelectorAll('p, span')) {
          final text = _cleanText(el.text);
          final sm = RegExp(r'(\d+)\s+Students?').firstMatch(text);
          if (sm != null) {
            studentCount = int.tryParse(sm.group(1)!) ?? 0;
            break;
          }
        }

        courses.add(Course(
          id: id,
          code: code,
          name: name,
          sks: sks,
          kelasType: kelasType,
          kelasName: kelasName,
          schedule: schedule,
          lecturerName: lecturer,
          prodi: prodi,
          studentCount: studentCount,
        ));
      } catch (_) {
        continue;
      }
    }

    return courses;
  }

  // --- PRESENSI ---

  Future<CoursePresensiResult> fetchPresensi(String courseId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.courseDetailUrl}/$courseId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 20));

    if (_isLoginPage(response.body)) throw SessionExpiredException();
    if (response.statusCode != 200) {
      throw Exception('Gagal mengambil data presensi');
    }

    return _parsePresensiHtml(response.body, courseId);
  }

  CoursePresensiResult _parsePresensiHtml(String html, String courseId) {
    final doc = html_parser.parse(html);

    // Extract course name from header
    String courseName = '';
    for (final el in doc.querySelectorAll('h1, h2, h3, h4')) {
      final text = _cleanText(el.text);
      if (text.contains('|')) {
        courseName = text;
        break;
      }
    }

    // Detect if any presensi is open today
    final bodyText = doc.body?.text ?? '';
    final hasOpenToday = !bodyText.contains('Tidak Ada Presensi yang harus dilakukan');

    // Parse individual pertemuan items
    final pertemuanList = <Pertemuan>[];
    // Look for elements containing "Pertemuan N Sesi N"
    final candidates = doc.querySelectorAll(
      '[class*="list-group-item"], [class*="card-body"] > div, .row > div',
    );

    for (final el in candidates) {
      final text = _cleanText(el.text);
      final m = RegExp(r'Pertemuan (\d+) Sesi (\d+)').firstMatch(text);
      if (m == null) continue;

      final number = int.parse(m.group(1)!);
      final session = int.parse(m.group(2)!);

      // Status: look for badge with "Open" or "Closed"
      PertemuanStatus status = PertemuanStatus.closed;
      for (final badge in el.querySelectorAll('.badge, span')) {
        final badgeText = _cleanText(badge.text).toLowerCase();
        if (badgeText.contains('open') || badgeText.contains('buka') || badgeText.contains('aktif')) {
          status = PertemuanStatus.open;
          break;
        }
      }

      // Time range
      final timeM = RegExp(r'(\d{2}:\d{2})\s*s/d\s*Jam\s*(\d{2}:\d{2})').firstMatch(text)
          ?? RegExp(r'(\d{2}:\d{2})\s*s/d\s*(\d{2}:\d{2})').firstMatch(text);
      final timeRange = timeM != null ? '${timeM.group(1)} - ${timeM.group(2)}' : '';

      // Date
      DateTime? date;
      final dateM = RegExp(r'(\d{1,2})\s+(\w+)\s+(\d{4})').firstMatch(text);
      if (dateM != null) {
        date = _parseIndonesianDate(
          '${dateM.group(1)} ${dateM.group(2)} ${dateM.group(3)}',
          '00:00',
        );
      }

      // Avoid duplicates
      if (!pertemuanList.any((p) => p.number == number && p.session == session)) {
        pertemuanList.add(Pertemuan(
          courseId: courseId,
          courseName: courseName,
          number: number,
          session: session,
          date: date,
          timeRange: timeRange,
          status: status,
        ));
      }
    }

    return CoursePresensiResult(
      courseId: courseId,
      courseName: courseName,
      hasOpenPresensiToday: hasOpenToday,
      pertemuanList: pertemuanList,
    );
  }

  String _cleanText(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

class CoursePresensiResult {
  final String courseId;
  final String courseName;
  final bool hasOpenPresensiToday;
  final List<Pertemuan> pertemuanList;

  const CoursePresensiResult({
    required this.courseId,
    required this.courseName,
    required this.hasOpenPresensiToday,
    required this.pertemuanList,
  });
}
