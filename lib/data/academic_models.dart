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

// ---- study planning ---------------------------------------------------------

/// What a study plan prepares for. Copies the date from the exam or
/// assignment so the plan survives if that source is deleted.
class StudyGoal {
  const StudyGoal({
    required this.id,
    required this.title,
    required this.target,
    required this.createdAt,
    required this.totalMinutes,
    required this.sessionMinutes,
    required this.weekdays,
    required this.startMinute,
    this.courseId,
    this.sourceId,
    this.docId,
    this.firstPage,
    this.lastPage,
  });

  final String id;
  final String title;
  final String? courseId;

  /// When the exam or deadline happens.
  final DateTime target;
  final DateTime createdAt;

  /// Id of the exam event or assignment this plan was made for, if any.
  final String? sourceId;

  /// Total study time the plan aims for, in minutes.
  final int totalMinutes;
  final int sessionMinutes;

  /// Days of the week (1 = Monday) sessions may fall on.
  final List<int> weekdays;

  /// Preferred session start, as minutes after midnight.
  final int startMinute;

  /// Optional reading range to cover across the sessions.
  final String? docId;
  final int? firstPage;
  final int? lastPage;

  StudyGoal copyWith({
    String? title,
    DateTime? target,
    int? totalMinutes,
    int? sessionMinutes,
    List<int>? weekdays,
    int? startMinute,
  }) => StudyGoal(
    id: id,
    title: title ?? this.title,
    courseId: courseId,
    target: target ?? this.target,
    createdAt: createdAt,
    sourceId: sourceId,
    totalMinutes: totalMinutes ?? this.totalMinutes,
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    weekdays: weekdays ?? this.weekdays,
    startMinute: startMinute ?? this.startMinute,
    docId: docId,
    firstPage: firstPage,
    lastPage: lastPage,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'courseId': courseId,
    'target': target.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'sourceId': sourceId,
    'totalMinutes': totalMinutes,
    'sessionMinutes': sessionMinutes,
    'weekdays': weekdays,
    'startMinute': startMinute,
    'docId': docId,
    'firstPage': firstPage,
    'lastPage': lastPage,
  };

  factory StudyGoal.fromJson(Map<String, dynamic> j) => StudyGoal(
    id: j['id'] as String,
    title: j['title'] as String,
    courseId: j['courseId'] as String?,
    target: DateTime.parse(j['target'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
    sourceId: j['sourceId'] as String?,
    totalMinutes: (j['totalMinutes'] as int?) ?? 60,
    sessionMinutes: (j['sessionMinutes'] as int?) ?? 60,
    weekdays: [
      for (final d in (j['weekdays'] as List? ?? const [1, 2, 3, 4, 5]))
        d as int,
    ],
    startMinute: (j['startMinute'] as int?) ?? 18 * 60,
    docId: j['docId'] as String?,
    firstPage: j['firstPage'] as int?,
    lastPage: j['lastPage'] as int?,
  );
}

/// One planned block of study time, tracked until it's done.
class StudySession {
  const StudySession({
    required this.id,
    required this.title,
    required this.start,
    required this.durationMin,
    this.goalId,
    this.courseId,
    this.done = false,
    this.link,
    this.pageEnd,
  });

  final String id;
  final String title;
  final String? goalId;
  final String? courseId;
  final DateTime start;
  final int durationMin;
  final bool done;

  /// Material to study; [MaterialLink.page] is where to start.
  final MaterialLink? link;

  /// Last page this session is meant to cover (with [link]'s page as first).
  final int? pageEnd;

  DateTime get end => start.add(Duration(minutes: durationMin));

  StudySession copyWith({
    String? title,
    DateTime? start,
    int? durationMin,
    bool? done,
    MaterialLink? link,
    bool clearLink = false,
  }) => StudySession(
    id: id,
    title: title ?? this.title,
    goalId: goalId,
    courseId: courseId,
    start: start ?? this.start,
    durationMin: durationMin ?? this.durationMin,
    done: done ?? this.done,
    link: clearLink ? null : (link ?? this.link),
    pageEnd: clearLink ? null : pageEnd,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'goalId': goalId,
    'courseId': courseId,
    'start': start.toIso8601String(),
    'durationMin': durationMin,
    'done': done,
    'link': link?.toJson(),
    'pageEnd': pageEnd,
  };

  factory StudySession.fromJson(Map<String, dynamic> j) => StudySession(
    id: j['id'] as String,
    title: j['title'] as String,
    goalId: j['goalId'] as String?,
    courseId: j['courseId'] as String?,
    start: DateTime.parse(j['start'] as String),
    durationMin: (j['durationMin'] as int?) ?? 60,
    done: (j['done'] as bool?) ?? false,
    link: MaterialLink.fromJson(j['link']),
    pageEnd: j['pageEnd'] as int?,
  );
}

/// How a plan is going.
enum PlanStatus {
  /// Every session is done.
  complete,

  /// Some past session hasn't been done.
  behind,

  /// Nothing overdue.
  onTrack,

  /// The target date has passed.
  past,
}

/// An exam or deadline that could use a plan.
class PlanTarget {
  const PlanTarget({
    required this.title,
    required this.date,
    required this.isExam,
    this.courseId,
    this.sourceId,
  });

  final String title;
  final DateTime date;
  final bool isExam;
  final String? courseId;
  final String? sourceId;
}

/// Summary numbers for a plan.
class PlanProgress {
  const PlanProgress({
    required this.doneMinutes,
    required this.plannedMinutes,
    required this.doneCount,
    required this.count,
  });

  final int doneMinutes;
  final int plannedMinutes;
  final int doneCount;
  final int count;

  double get fraction =>
      plannedMinutes == 0 ? 0 : (doneMinutes / plannedMinutes).clamp(0.0, 1.0);
}
