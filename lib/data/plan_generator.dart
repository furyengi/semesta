import 'academic_models.dart';

/// A session the generator wants to schedule (not yet stored).
class PlannedSession {
  const PlannedSession({
    required this.title,
    required this.start,
    required this.durationMin,
    this.page,
    this.pageEnd,
  });

  final String title;
  final DateTime start;
  final int durationMin;
  final int? page;
  final int? pageEnd;
}

/// Inputs for spreading study time over the days before a target.
class PlanRequest {
  const PlanRequest({
    required this.now,
    required this.target,
    required this.totalMinutes,
    required this.sessionMinutes,
    required this.weekdays,
    required this.startMinute,
    required this.baseTitle,
    this.firstPage,
    this.lastPage,
    this.isBusy,
  });

  final DateTime now;
  final DateTime target;
  final int totalMinutes;
  final int sessionMinutes;
  final Set<int> weekdays;
  final int startMinute;
  final String baseTitle;
  final int? firstPage;
  final int? lastPage;

  /// True if [start]..[end] clashes with something already scheduled.
  final bool Function(DateTime start, DateTime end)? isBusy;
}

const _earliestMinute = 8 * 60;
const _latestEndMinute = 22 * 60;
const _breakMinutes = 15;
const _slotStep = 30;

/// Spreads [PlanRequest.totalMinutes] across the allowed days between now and
/// the day before the target, evenly, without clashing with busy times.
///
/// Sessions are as long as [PlanRequest.sessionMinutes] (the last may be
/// shorter). If there are more sessions than days, days get several. When a
/// reading range is given it is split evenly across the sessions.
List<PlannedSession> generatePlan(PlanRequest r) {
  if (r.totalMinutes <= 0 || r.sessionMinutes <= 0) return const [];

  final today = dateOnly(r.now);
  final lastDay = addDays(dateOnly(r.target), -1);
  final nowMinute = r.now.hour * 60 + r.now.minute;

  final days = <DateTime>[];
  for (var d = today; !d.isAfter(lastDay); d = addDays(d, 1)) {
    if (!r.weekdays.contains(d.weekday)) continue;
    // Today only counts if the preferred start hasn't passed yet.
    if (sameDay(d, today) && r.startMinute <= nowMinute) continue;
    days.add(d);
  }
  if (days.isEmpty) return const [];

  final count = (r.totalMinutes / r.sessionMinutes).ceil();
  final placedOnDay = <int, int>{};
  final out = <PlannedSession>[];

  final pages = _splitPages(r.firstPage, r.lastPage, count);

  for (var i = 0; i < count; i++) {
    final dayIndex = (((i + 0.5) * days.length) / count).floor().clamp(
      0,
      days.length - 1,
    );
    final day = days[dayIndex];
    final nth = placedOnDay.update(dayIndex, (n) => n + 1, ifAbsent: () => 0);

    final minutes = i == count - 1
        ? r.totalMinutes - (count - 1) * r.sessionMinutes
        : r.sessionMinutes;
    final preferred = r.startMinute + nth * (r.sessionMinutes + _breakMinutes);
    final start = _findSlot(day, preferred, minutes, r);

    final range = pages == null ? null : pages[i];
    out.add(
      PlannedSession(
        title: range == null
            ? '${r.baseTitle} · ${i + 1}/$count'
            : '${r.baseTitle} · pp. ${range.$1}–${range.$2}',
        start: start,
        durationMin: minutes,
        page: range?.$1,
        pageEnd: range?.$2,
      ),
    );
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

DateTime _at(DateTime day, int minute) =>
    DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);

/// The preferred time if free, else the nearest free slot (later first, then
/// earlier) within the allowed hours; falls back to the preferred time.
DateTime _findSlot(DateTime day, int preferred, int minutes, PlanRequest r) {
  final busy = r.isBusy;
  bool free(int m) {
    if (m < _earliestMinute || m + minutes > _latestEndMinute) return false;
    return busy == null || !busy(_at(day, m), _at(day, m + minutes));
  }

  if (free(preferred)) return _at(day, preferred);
  for (
    var m = preferred + _slotStep;
    m + minutes <= _latestEndMinute;
    m += _slotStep
  ) {
    if (free(m)) return _at(day, m);
  }
  for (var m = preferred - _slotStep; m >= _earliestMinute; m -= _slotStep) {
    if (free(m)) return _at(day, m);
  }
  return _at(day, preferred.clamp(_earliestMinute, _latestEndMinute - minutes));
}

/// Splits first..last into [count] consecutive chunks (inclusive ranges).
/// Returns null without a valid range. With fewer pages than sessions, later
/// sessions repeat the final page.
List<(int, int)>? _splitPages(int? first, int? last, int count) {
  if (first == null || last == null || last < first || count < 1) return null;
  final total = last - first + 1;
  return [
    for (var i = 0; i < count; i++)
      () {
        final a = first + (i * total) ~/ count;
        final b = first + ((i + 1) * total) ~/ count - 1;
        return b < a ? (a, a) : (a, b);
      }(),
  ];
}
