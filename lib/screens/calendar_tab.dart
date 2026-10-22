import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../data/store_scope.dart';
import '../theme/motion.dart';
import '../widgets/brutal.dart';
import '../widgets/event_sheets.dart';
import '../widgets/format.dart';
import '../widgets/schedule_tiles.dart';
import 'home_screen.dart' show contentGutter;

enum CalendarView { day, week, month }

/// Day, week and month views of the timetable, deadlines included.
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.selectedDay});

  /// The day the shell's "Add event" button creates events on.
  final ValueNotifier<DateTime> selectedDay;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  CalendarView _view = CalendarView.week;
  bool _reverse = false;

  DateTime get _day => widget.selectedDay.value;

  void _select(DateTime d, {bool? reverse}) {
    setState(() {
      _reverse = reverse ?? d.isBefore(_day);
      widget.selectedDay.value = dateOnly(d);
    });
  }

  void _shift(int dir) {
    final d = _day;
    final next = switch (_view) {
      CalendarView.day => addDays(d, dir),
      CalendarView.week => addDays(d, 7 * dir),
      CalendarView.month => _addMonths(d, dir),
    };
    _select(next, reverse: dir < 0);
  }

  static DateTime _addMonths(DateTime d, int n) {
    final first = DateTime(d.year, d.month + n);
    final last = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, d.day > last ? last : d.day);
  }

  String get _title {
    final d = _day;
    switch (_view) {
      case CalendarView.day:
        return '${weekdayLong[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1].substring(0, 3)}';
      case CalendarView.week:
        final a = startOfWeek(d), b = addDays(a, 6);
        final am = monthNames[a.month - 1].substring(0, 3);
        final bm = monthNames[b.month - 1].substring(0, 3);
        return a.month == b.month
            ? '${a.day} – ${b.day} $bm'
            : '${a.day} $am – ${b.day} $bm';
      case CalendarView.month:
        return '${monthNames[d.month - 1]} ${d.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final gutter = contentGutter(context);
    final today = dateOnly(DateTime.now());
    final isToday = _view == CalendarView.day
        ? sameDay(_day, today)
        : _view == CalendarView.week
        ? sameDay(startOfWeek(_day), startOfWeek(today))
        : (_day.year == today.year && _day.month == today.month);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 12, gutter - 8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calendar', style: text.labelLarge),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.short4),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: AlignmentDirectional.centerStart,
                          children: [...previous, ?current],
                        ),
                        child: Text(
                          _title,
                          key: ValueKey(_title),
                          style: text.headlineSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      duration: Motion.of(context, Motion.short4),
                      opacity: isToday ? 0 : 1,
                      child: TextButton(
                        onPressed: isToday ? null : () => _select(today),
                        child: const Text('Today'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Previous',
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _shift(-1),
                    ),
                    IconButton(
                      tooltip: 'Next',
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _shift(1),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<CalendarView>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: CalendarView.day,
                          label: Text('Day'),
                        ),
                        ButtonSegment(
                          value: CalendarView.week,
                          label: Text('Week'),
                        ),
                        ButtonSegment(
                          value: CalendarView.month,
                          label: Text('Month'),
                        ),
                      ],
                      selected: {_view},
                      onSelectionChanged: (s) =>
                          setState(() => _view = s.first),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PageTransitionSwitcher(
              reverse: _reverse,
              duration: Motion.of(context, Motion.medium2),
              transitionBuilder: (child, animation, secondary) =>
                  SharedAxisTransition(
                    animation: animation,
                    secondaryAnimation: secondary,
                    transitionType: SharedAxisTransitionType.horizontal,
                    fillColor: Colors.transparent,
                    child: child,
                  ),
              child: KeyedSubtree(
                key: ValueKey(
                  '$_view-${_view == CalendarView.month ? '${_day.year}-${_day.month}' : _day}',
                ),
                child: switch (_view) {
                  CalendarView.day => DayView(day: _day, gutter: gutter),
                  CalendarView.week => WeekView(
                    day: _day,
                    gutter: gutter,
                    onOpenDay: (d) {
                      setState(() => _view = CalendarView.day);
                      _select(d, reverse: false);
                    },
                  ),
                  CalendarView.month => MonthView(
                    day: _day,
                    gutter: gutter,
                    onSelect: (d) => _selectInMonth(d),
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Selecting a day inside the visible month shouldn't replay the slide
  /// transition, so only update the notifier and rebuild.
  void _selectInMonth(DateTime d) {
    if (d.month != _day.month || d.year != _day.year) {
      _select(d);
    } else {
      setState(() => widget.selectedDay.value = dateOnly(d));
    }
  }
}

// ---- Day ---------------------------------------------------------------------

const double _hourHeight = 64;
const double _timeGutter = 60;

class DayView extends StatefulWidget {
  const DayView({super.key, required this.day, required this.gutter});

  final DateTime day;
  final double gutter;

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final occ = store.occurrencesOn(widget.day);
    final now = DateTime.now();
    final focusHour = occ.isNotEmpty
        ? occ.first.start.hour
        : (sameDay(widget.day, now) ? now.hour : 8);
    _scroll = ScrollController(
      initialScrollOffset: ((focusHour - 1).clamp(0, 16)) * _hourHeight,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final occ = store.occurrencesOn(widget.day);
    final due = store.assignmentsDueOn(widget.day);
    final lanes = _layout(occ);
    final now = DateTime.now();
    final showNow = sameDay(widget.day, now);

    return Column(
      children: [
        if (due.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(widget.gutter, 0, widget.gutter, 8),
            child: Column(
              children: [
                for (final a in due)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AssignmentTile(assignment: a, showCourse: true),
                  ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(widget.gutter, 0, widget.gutter, 100),
            child: SizedBox(
              height: 24 * _hourHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth - _timeGutter;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var h = 0; h < 24; h++) ...[
                        Positioned(
                          top: h * _hourHeight,
                          left: _timeGutter,
                          right: 0,
                          child: Divider(
                            height: 1,
                            color: scheme.outlineVariant,
                          ),
                        ),
                        Positioned(
                          top: h * _hourHeight - 8,
                          left: 0,
                          width: _timeGutter - 8,
                          child: h == 0
                              ? const SizedBox.shrink()
                              : Text(
                                  // "9 AM" rather than "9:00 AM" to stay on one line.
                                  formatTime(
                                    context,
                                    DateTime(2000, 1, 1, h),
                                  ).replaceFirst(RegExp(r':00(?= )'), ''),
                                  softWrap: false,
                                  textAlign: TextAlign.end,
                                  style: text.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ],
                      for (final l in lanes)
                        Positioned(
                          top:
                              l.occurrence.start.hour * _hourHeight +
                              l.occurrence.start.minute / 60 * _hourHeight,
                          height:
                              (l.occurrence.event.durationMin /
                                      60 *
                                      _hourHeight)
                                  .clamp(34.0, 24 * _hourHeight),
                          left:
                              _timeGutter + 6 + l.lane * (width - 6) / l.lanes,
                          width: (width - 6) / l.lanes - 4,
                          child: _EventBlock(occurrence: l.occurrence),
                        ),
                      if (showNow)
                        Positioned(
                          top:
                              (now.hour * 60 + now.minute) / 60 * _hourHeight -
                              4,
                          left: _timeGutter - 4,
                          right: 0,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: scheme.tertiary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: scheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Placed {
  _Placed(this.occurrence, this.lane);

  final Occurrence occurrence;
  final int lane;
  int lanes = 1;
}

/// Places overlapping events side by side.
List<_Placed> _layout(List<Occurrence> occ) {
  final placed = <_Placed>[];
  final laneEnds = <DateTime>[];
  for (final o in occ) {
    var lane = laneEnds.indexWhere((end) => !end.isAfter(o.start));
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(o.end);
    } else {
      laneEnds[lane] = o.end;
    }
    placed.add(_Placed(o, lane));
  }
  for (final p in placed) {
    var maxLane = p.lane;
    for (final q in placed) {
      final overlap =
          q.occurrence.start.isBefore(p.occurrence.end) &&
          p.occurrence.start.isBefore(q.occurrence.end);
      if (overlap && q.lane > maxLane) maxLane = q.lane;
    }
    p.lanes = maxLane + 1;
  }
  return placed;
}

class _EventBlock extends StatelessWidget {
  const _EventBlock({required this.occurrence});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final e = occurrence.event;
    final color = store.course(e.courseId)?.color ?? scheme.primary;
    return Semantics(
      button: true,
      label:
          '${e.title}, ${formatTimeRange(context, occurrence.start, occurrence.end)}',
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(color.withValues(alpha: .28), scheme.surface),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showEventDetails(context, occurrence),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: text.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatTimeRange(context, occurrence.start, occurrence.end),
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Week --------------------------------------------------------------------

class WeekView extends StatelessWidget {
  const WeekView({
    super.key,
    required this.day,
    required this.gutter,
    required this.onOpenDay,
  });

  final DateTime day;
  final double gutter;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final monday = startOfWeek(day);
    final today = dateOnly(DateTime.now());

    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 100),
      children: [
        for (var i = 0; i < 7; i++) ...[
          Builder(
            builder: (context) {
              final d = addDays(monday, i);
              final occ = store.occurrencesOn(d);
              final due = store.assignmentsDueOn(d);
              final isToday = sameDay(d, today);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onOpenDay(d),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? scheme.primary
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${d.day}',
                                style: text.titleSmall?.copyWith(
                                  color: isToday
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              weekdayLong[d.weekday - 1],
                              style: text.titleSmall?.copyWith(
                                color: isToday ? scheme.primary : null,
                              ),
                            ),
                            const Spacer(),
                            if (occ.isEmpty && due.isEmpty)
                              Text(
                                'Free',
                                style: text.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    for (final o in occ)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Reveal(child: OccurrenceTile(occurrence: o)),
                      ),
                    for (final a in due)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AssignmentTile(assignment: a, showCourse: true),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

// ---- Month -------------------------------------------------------------------

class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.day,
    required this.gutter,
    required this.onSelect,
  });

  final DateTime day;
  final double gutter;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final first = DateTime(day.year, day.month);
    final gridStart = startOfWeek(first);
    final today = dateOnly(DateTime.now());
    final occ = store.occurrencesOn(day);
    final due = store.assignmentsDueOn(day);

    Widget cell(DateTime d) {
      final inMonth = d.month == day.month;
      final selected = sameDay(d, day);
      final isToday = sameDay(d, today);
      final colors = <Color>[];
      for (final o in store.occurrencesOn(d)) {
        final c = store.course(o.event.courseId)?.color ?? scheme.primary;
        if (!colors.contains(c)) colors.add(c);
      }
      if (store.assignmentsDueOn(d).isNotEmpty) colors.add(scheme.tertiary);
      return Semantics(
        button: true,
        selected: selected,
        label: '${formatShortDate(d)}${colors.isEmpty ? '' : ', has events'}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelect(d),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: Motion.of(context, Motion.short4),
                  curve: Motion.emphasized,
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !selected
                        ? Border.all(color: scheme.primary, width: 2)
                        : null,
                  ),
                  child: Text(
                    '${d.day}',
                    style: text.bodyMedium?.copyWith(
                      fontWeight: selected || isToday ? FontWeight.w700 : null,
                      color: selected
                          ? scheme.onPrimary
                          : inMonth
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: .35),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final c in colors.take(3))
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 100),
      children: [
        Row(
          children: [
            for (final w in weekdayShort)
              Expanded(
                child: Center(
                  child: Text(
                    w.substring(0, 1),
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < 6; r++)
          // Skip a trailing row that is entirely the next month.
          if (!addDays(
            gridStart,
            r * 7,
          ).isAfter(DateTime(day.year, day.month + 1, 0)))
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(child: cell(addDays(gridStart, r * 7 + c))),
                ],
              ),
            ),
        const Divider(height: 28),
        Text(
          relativeDay(day),
          style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        if (occ.isEmpty && due.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Nothing scheduled', style: text.bodyMedium),
            ),
          ),
        for (final o in occ)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OccurrenceTile(occurrence: o),
          ),
        for (final a in due)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AssignmentTile(assignment: a, showCourse: true),
          ),
      ],
    );
  }
}
