import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/academic_models.dart';
import 'package:semesta/data/plan_generator.dart';

// Monday 19 Oct 2026, 08:00.
final _now = DateTime(2026, 10, 19, 8);

PlanRequest _req({
  DateTime? target,
  int total = 360,
  int session = 60,
  Set<int> weekdays = const {1, 2, 3, 4, 5},
  int startMinute = 18 * 60,
  int? first,
  int? last,
  bool Function(DateTime, DateTime)? busy,
  DateTime? now,
}) => PlanRequest(
  now: now ?? _now,
  target: target ?? DateTime(2026, 10, 30, 10), // Friday
  totalMinutes: total,
  sessionMinutes: session,
  weekdays: weekdays,
  startMinute: startMinute,
  baseTitle: 'Exam',
  firstPage: first,
  lastPage: last,
  isBusy: busy,
);

void main() {
  test('creates enough sessions to cover the time, none on or after the target day', () {
    final plan = generatePlan(_req());
    expect(plan, hasLength(6));
    expect(plan.fold(0, (a, s) => a + s.durationMin), 360);
    expect(plan.every((s) => s.start.isBefore(DateTime(2026, 10, 30))), isTrue);
    expect(plan.every((s) => s.start.hour == 18), isTrue);
  });

  test('only uses the allowed weekdays', () {
    final plan = generatePlan(_req(weekdays: {2, 4})); // Tue, Thu
    expect(plan.every((s) => {2, 4}.contains(s.start.weekday)), isTrue);
  });

  test('spreads sessions evenly instead of piling them up at the start', () {
    final plan = generatePlan(
      _req(total: 180, weekdays: {1, 2, 3, 4, 5, 6, 7}),
    );
    final days = plan.map((s) => dateOnly(s.start)).toList();
    expect(days.toSet().length, 3); // one per day
    final gaps = [
      for (var i = 1; i < days.length; i++)
        days[i].difference(days[i - 1]).inDays,
    ];
    // Even-ish: no gap more than one day bigger than another.
    expect(
      gaps.reduce((a, b) => a > b ? a : b) -
          gaps.reduce((a, b) => a < b ? a : b),
      lessThanOrEqualTo(1),
    );
    // Centred in the available window rather than starting today.
    expect(days.first.isAfter(dateOnly(_now)), isTrue);
  });

  test(
    'puts several sessions on a day when there are more sessions than days',
    () {
      final plan = generatePlan(
        _req(
          target: DateTime(2026, 10, 22, 10), // Mon, Tue, Wed available
          total: 6 * 60,
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      expect(plan, hasLength(6));
      final perDay = <DateTime, int>{};
      for (final s in plan) {
        perDay.update(dateOnly(s.start), (n) => n + 1, ifAbsent: () => 1);
      }
      expect(perDay.values.every((n) => n == 2), isTrue);
      // Two on the same day don't overlap.
      final day = plan
          .where((s) => sameDay(s.start, plan.first.start))
          .toList();
      expect(
        day[0].start
            .add(Duration(minutes: day[0].durationMin))
            .isAfter(day[1].start),
        isFalse,
      );
    },
  );

  test('the last session is shorter when the time does not divide evenly', () {
    final plan = generatePlan(_req(total: 150, session: 60));
    expect(plan.map((s) => s.durationMin).toList(), [60, 60, 30]);
  });

  test('today only counts if the preferred start is still ahead', () {
    final early = generatePlan(
      _req(
        target: DateTime(2026, 10, 21, 9),
        total: 60,
        weekdays: {1, 2, 3, 4, 5, 6, 7},
      ),
    );
    expect(early.single.start.day, anyOf(19, 20)); // Mon 18:00 is still ahead
    final late = generatePlan(
      _req(
        target: DateTime(2026, 10, 21, 9),
        total: 60,
        weekdays: {1, 2, 3, 4, 5, 6, 7},
        now: DateTime(2026, 10, 19, 19),
      ),
    );
    expect(late.single.start.day, 20); // Mon 18:00 has gone; only Tue is left
  });

  test('returns nothing when no allowed day is available', () {
    expect(
      generatePlan(_req(target: DateTime(2026, 10, 19, 12))),
      isEmpty,
    ); // same day
    expect(
      generatePlan(_req(weekdays: {6, 7}, target: DateTime(2026, 10, 24))),
      isEmpty,
    );
    expect(generatePlan(_req(total: 0)), isEmpty);
  });

  test('moves a session off a busy slot to the nearest free one', () {
    // Everything between 17:30 and 19:00 is taken.
    bool busy(DateTime s, DateTime e) =>
        s.isBefore(DateTime(s.year, s.month, s.day, 19)) &&
        e.isAfter(DateTime(s.year, s.month, s.day, 17, 30));
    final plan = generatePlan(_req(busy: busy, total: 120));
    for (final s in plan) {
      expect(
        s.start.hour * 60 + s.start.minute,
        19 * 60,
      ); // first free step after
    }
  });

  test('splits a reading range across sessions', () {
    final plan = generatePlan(
      _req(total: 240, first: 1, last: 100),
    ); // 4 sessions
    expect(plan.map((s) => (s.page, s.pageEnd)).toList(), [
      (1, 25),
      (26, 50),
      (51, 75),
      (76, 100),
    ]);
    expect(plan.first.title, 'Exam · pp. 1–25');
  });

  test('uneven page ranges still cover every page exactly once', () {
    final plan = generatePlan(
      _req(total: 180, first: 10, last: 20),
    ); // 11 pages, 3 sessions
    final covered = <int>[];
    for (final s in plan) {
      for (var p = s.page!; p <= s.pageEnd!; p++) {
        covered.add(p);
      }
    }
    expect(covered, [for (var p = 10; p <= 20; p++) p]);
  });

  test('without a range sessions are numbered', () {
    final plan = generatePlan(_req(total: 120));
    expect(plan.map((s) => s.title), ['Exam · 1/2', 'Exam · 2/2']);
    expect(plan.first.page, isNull);
  });
}
