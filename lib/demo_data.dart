import 'core/notifier.dart';
import 'core/widget_backend.dart';
import 'data/widget_data.dart';
import 'data/academic_models.dart';
import 'data/reminder_planner.dart';
import 'data/library_store.dart';

/// Build with `--dart-define=SEMESTA_DEMO=true` to fill an empty app with a
/// sample semester (for screenshots and demos). Off by default.
const bool kDemoData = bool.fromEnvironment('SEMESTA_DEMO');

void seedDemoSemester(LibraryStore store) {
  if (store.courses.isNotEmpty) return;
  final now = DateTime.now();
  final monday = startOfWeek(now);
  final doc = store.docs.isEmpty ? null : store.docs.first;
  MaterialLink? link(int page) =>
      doc == null ? null : MaterialLink(docId: doc.id, page: page);
  DateTime at(int dayOffset, int h, [int m = 0]) =>
      DateTime(monday.year, monday.month, monday.day + dayOffset, h, m);

  final algo = store.addCourse(
    name: 'Algorithms',
    code: 'CS101',
    instructor: 'Dr. Okafor',
    colorIndex: 1,
    iconKey: 'code',
  );
  final chem = store.addCourse(
    name: 'Organic Chemistry',
    code: 'CHEM2',
    instructor: 'Prof. Lindqvist',
    colorIndex: 6,
    iconKey: 'science',
  );
  final linalg = store.addCourse(
    name: 'Linear Algebra',
    code: 'MATH210',
    colorIndex: 7,
    iconKey: 'calculate',
  );
  final art = store.addCourse(
    name: 'Art History',
    code: 'ART150',
    colorIndex: 4,
    iconKey: 'brush',
  );

  if (doc != null) store.setDocCourse(doc.id, algo.id);

  void weekly(
    Course c,
    EventKind k,
    int day,
    int h,
    int m,
    int mins,
    String where, {
    MaterialLink? l,
  }) => store.addEvent(
    title: '${c.name} ${k.label}',
    kind: k,
    start: at(day, h, m),
    durationMin: mins,
    courseId: c.id,
    weekly: true,
    location: where,
    link: l,
  );

  weekly(algo, EventKind.lecture, 0, 9, 0, 60, 'Hall B', l: link(2));
  weekly(algo, EventKind.practical, 2, 14, 0, 120, 'Lab 4', l: link(3));
  weekly(chem, EventKind.lecture, 1, 10, 30, 90, 'Science 201');
  weekly(chem, EventKind.lecture, 3, 10, 30, 90, 'Science 201');
  weekly(linalg, EventKind.lecture, 0, 11, 0, 90, 'Maths 12');
  weekly(linalg, EventKind.lecture, 4, 9, 0, 60, 'Maths 12');
  weekly(art, EventKind.lecture, 2, 16, 0, 60, 'Gallery Room');

  store.addEvent(
    title: 'Algorithms midterm',
    kind: EventKind.exam,
    start: at(16, 10),
    durationMin: 120,
    courseId: algo.id,
    location: 'Exam Hall',
  );
  store.addEvent(
    title: 'Office hours',
    kind: EventKind.other,
    start: now.add(const Duration(minutes: 50)),
    durationMin: 45,
    courseId: algo.id,
    location: 'Room 3.14',
    link: link(4),
  );

  final midterm = store.events.firstWhere(
    (e) => e.title == 'Algorithms midterm',
  );
  store.createPlan(
    title: 'Algorithms midterm',
    target: midterm.start,
    totalMinutes: 4 * 60,
    sessionMinutes: 60,
    weekdays: {1, 2, 3, 4, 5, 7},
    startMinute: 18 * 60,
    courseId: algo.id,
    sourceId: midterm.id,
    docId: doc?.id,
    firstPage: doc == null ? null : 1,
    lastPage: doc == null ? null : 4,
  );
  store.createPlan(
    title: 'Chemistry lab prep',
    target: at(10, 9),
    totalMinutes: 3 * 60,
    sessionMinutes: 45,
    weekdays: {2, 4, 6},
    startMinute: 17 * 60 + 30,
    courseId: chem.id,
  );

  DateTime due(int days, [int h = 23, int m = 59]) {
    final d = addDays(dateOnly(now), days);
    return DateTime(d.year, d.month, d.day, h, m);
  }

  store.addAssignment(
    courseId: algo.id,
    title: 'Problem set 3',
    due: due(1),
    link: link(2),
  );
  store.addAssignment(
    courseId: chem.id,
    title: 'Lab report: esterification',
    due: due(3, 17, 0),
  );
  store.addAssignment(
    courseId: art.id,
    title: 'Essay: Impressionism',
    due: due(6),
  );
  store.addAssignment(
    courseId: linalg.id,
    title: 'Quiz prep: eigenvalues',
    due: due(2, 12, 0),
  );
}

/// Stands in for notifications in demo builds on platforms that have none
/// (like the web preview), so the reminder screens can be tried.
class DemoNotifier extends NoopNotifier {
  @override
  bool get supported => true;

  @override
  Future<bool> areEnabled() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> replaceAll(List<ReminderSpec> specs) async {}
}

/// Stands in for home-screen widgets in demo builds on platforms that have
/// none, so the widget settings and previews can be tried.
class DemoWidgetBackend extends NoopWidgetBackend {
  @override
  bool get supported => true;

  @override
  Future<bool> canPin() async => true;

  @override
  Future<bool> pin(WidgetKind kind) async => true;
}
