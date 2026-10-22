import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Icons a course can use, keyed by a stable string for persistence.
abstract final class CourseIcons {
  static const Map<String, IconData> all = {
    'school': Icons.school_outlined,
    'science': Icons.science_outlined,
    'calculate': Icons.calculate_outlined,
    'code': Icons.code_rounded,
    'book': Icons.menu_book_outlined,
    'biotech': Icons.biotech_outlined,
    'gavel': Icons.gavel_rounded,
    'brush': Icons.brush_outlined,
    'language': Icons.translate_rounded,
    'business': Icons.business_center_outlined,
    'history': Icons.account_balance_outlined,
    'health': Icons.medical_services_outlined,
  };

  static IconData resolve(String key) => all[key] ?? Icons.school_outlined;
}

class Course {
  const Course({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.iconKey,
    required this.createdAt,
    this.code = '',
    this.instructor = '',
    this.notes = '',
  });

  final String id;
  final String name;

  /// Short course code such as "CS101". May be empty.
  final String code;
  final String instructor;
  final String notes;
  final int colorIndex;
  final String iconKey;
  final DateTime createdAt;

  Color get color =>
      AccentPalette.colors[colorIndex % AccentPalette.colors.length];
  IconData get icon => CourseIcons.resolve(iconKey);

  Course copyWith({
    String? name,
    String? code,
    String? instructor,
    String? notes,
    int? colorIndex,
    String? iconKey,
  }) => Course(
    id: id,
    name: name ?? this.name,
    code: code ?? this.code,
    instructor: instructor ?? this.instructor,
    notes: notes ?? this.notes,
    colorIndex: colorIndex ?? this.colorIndex,
    iconKey: iconKey ?? this.iconKey,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'instructor': instructor,
    'notes': notes,
    'colorIndex': colorIndex,
    'iconKey': iconKey,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Course.fromJson(Map<String, dynamic> j) => Course(
    id: j['id'] as String,
    name: j['name'] as String,
    code: (j['code'] as String?) ?? '',
    instructor: (j['instructor'] as String?) ?? '',
    notes: (j['notes'] as String?) ?? '',
    colorIndex: (j['colorIndex'] as int?) ?? 0,
    iconKey: (j['iconKey'] as String?) ?? 'school',
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

enum EventKind {
  lecture('Lecture', Icons.co_present_outlined),
  practical('Practical', Icons.science_outlined),
  exam('Exam', Icons.quiz_outlined),
  study('Study', Icons.menu_book_outlined),
  other('Other', Icons.event_outlined);

  const EventKind(this.label, this.icon);

  final String label;
  final IconData icon;

  static EventKind byName(String? n) => EventKind.values.firstWhere(
    (k) => k.name == n,
    orElse: () => EventKind.other,
  );
}

/// A pointer to a place in a library document.
class MaterialLink {
  const MaterialLink({required this.docId, this.page});

  final String docId;

  /// 1-based page to open at, or null for the document's saved position.
  final int? page;

  Map<String, dynamic> toJson() => {'docId': docId, 'page': page};

  static MaterialLink? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final id = j['docId'];
    if (id is! String) return null;
    return MaterialLink(docId: id, page: j['page'] as int?);
  }
}

/// A timetable entry: a one-off event, or a class that repeats weekly.
class ScheduleEvent {
  const ScheduleEvent({
    required this.id,
    required this.title,
    required this.kind,
    required this.start,
    required this.durationMin,
    this.courseId,
    this.weekly = false,
    this.until,
    this.location = '',
    this.link,
  });

  final String id;
  final String title;
  final EventKind kind;
  final String? courseId;

  /// First occurrence. For weekly events the weekday and time of day repeat.
  final DateTime start;
  final int durationMin;
  final bool weekly;

  /// Last day a weekly event repeats on (inclusive). Null means no end.
  final DateTime? until;
  final String location;
  final MaterialLink? link;

  ScheduleEvent copyWith({
    String? title,
    EventKind? kind,
    String? courseId,
    bool clearCourse = false,
    DateTime? start,
    int? durationMin,
    bool? weekly,
    DateTime? until,
    bool clearUntil = false,
    String? location,
    MaterialLink? link,
    bool clearLink = false,
  }) => ScheduleEvent(
    id: id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    courseId: clearCourse ? null : (courseId ?? this.courseId),
    start: start ?? this.start,
    durationMin: durationMin ?? this.durationMin,
    weekly: weekly ?? this.weekly,
    until: clearUntil ? null : (until ?? this.until),
    location: location ?? this.location,
    link: clearLink ? null : (link ?? this.link),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'courseId': courseId,
    'start': start.toIso8601String(),
    'durationMin': durationMin,
    'weekly': weekly,
    'until': until?.toIso8601String(),
    'location': location,
    'link': link?.toJson(),
  };

  factory ScheduleEvent.fromJson(Map<String, dynamic> j) => ScheduleEvent(
    id: j['id'] as String,
    title: j['title'] as String,
    kind: EventKind.byName(j['kind'] as String?),
    courseId: j['courseId'] as String?,
    start: DateTime.parse(j['start'] as String),
    durationMin: (j['durationMin'] as int?) ?? 60,
    weekly: (j['weekly'] as bool?) ?? false,
    until: j['until'] == null ? null : DateTime.parse(j['until'] as String),
    location: (j['location'] as String?) ?? '',
    link: MaterialLink.fromJson(j['link']),
  );
}

/// One concrete time an event happens.
class Occurrence {
  const Occurrence(this.event, this.start);

  final ScheduleEvent event;
  final DateTime start;

  DateTime get end => start.add(Duration(minutes: event.durationMin));
}

class Assignment {
  const Assignment({
    required this.id,
    required this.courseId,
    required this.title,
    required this.due,
    this.done = false,
    this.link,
  });

  final String id;
  final String courseId;
  final String title;
  final DateTime due;
  final bool done;
  final MaterialLink? link;

  Assignment copyWith({
    String? title,
    DateTime? due,
    bool? done,
    MaterialLink? link,
    bool clearLink = false,
  }) => Assignment(
    id: id,
    courseId: courseId,
    title: title ?? this.title,
    due: due ?? this.due,
    done: done ?? this.done,
    link: clearLink ? null : (link ?? this.link),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseId': courseId,
    'title': title,
    'due': due.toIso8601String(),
    'done': done,
    'link': link?.toJson(),
  };

  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
    id: j['id'] as String,
    courseId: j['courseId'] as String,
    title: j['title'] as String,
    due: DateTime.parse(j['due'] as String),
    done: (j['done'] as bool?) ?? false,
    link: MaterialLink.fromJson(j['link']),
  );
}

// ---- date helpers ---------------------------------------------------------

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) => addDays(dateOnly(d), 1 - d.weekday);

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
