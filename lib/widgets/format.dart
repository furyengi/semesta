import 'package:flutter/material.dart';

import '../data/academic_models.dart';

/// "9:00 AM" or "09:00", following the device's 12/24-hour setting.
String formatTime(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

String formatTimeRange(BuildContext context, DateTime a, DateTime b) =>
    '${formatTime(context, a)} – ${formatTime(context, b)}';

/// "Mon 21 Oct".
String formatShortDate(DateTime d) =>
    '${weekdayShort[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1].substring(0, 3)}';

/// "Today", "Tomorrow", "Yesterday", or a short date.
String relativeDay(DateTime d, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = dateOnly(d).difference(today).inDays;
  return switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => formatShortDate(d),
  };
}

/// "Today, 9:00 AM" or "Wed 23 Oct, 9:00 AM".
String formatWhen(BuildContext context, DateTime d, {DateTime? now}) =>
    '${relativeDay(d, now: now)}, ${formatTime(context, d)}';

String formatDuration(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}
