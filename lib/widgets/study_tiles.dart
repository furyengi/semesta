import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../data/store_scope.dart';
import '../screens/goal_screen.dart';
import '../theme/motion.dart';
import 'format.dart';
import 'material_link.dart';
import 'plan_sheets.dart';

/// "Today", "Tomorrow", "in 5 days" or "3 days ago".
String daysLeftLabel(DateTime target, {DateTime? now}) {
  final days = dateOnly(target)
      .difference(dateOnly(now ?? DateTime.now()))
      .inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days > 1) return 'in $days days';
  if (days == -1) return 'Yesterday';
  return '${-days} days ago';
}

String formatHours(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// A planned study session with a tick box. Tap to edit; the menu can move
/// or delete it.
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    this.showDate = false,
    this.showGoal = false,
  });

  final StudySession session;
  final bool showDate;
  final bool showGoal;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = session;
    final missed = !s.done && s.end.isBefore(DateTime.now());
    final course = store.course(s.courseId);
    final label = materialLabel(store, s.link);
    final subtitle = [
      if (showDate) formatShortDate(s.start),
      formatTimeRange(context, s.start, s.end),
      if (showGoal) ?store.goal(s.goalId)?.title else ?course?.name,
    ].join(' · ');

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showSessionEditor(context, existing: s),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: course?.color ?? scheme.secondary),
              Checkbox(
                value: s.done,
                shape: const CircleBorder(),
                onChanged: (_) => store.toggleSession(s.id),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: Motion.of(context, Motion.short4),
                        style: (text.titleSmall ?? const TextStyle()).copyWith(
                          decoration: s.done
                              ? TextDecoration.lineThrough
                              : null,
                          color: s.done
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                        child: Text(
                          s.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        missed ? 'Missed · $subtitle' : subtitle,
                        style: text.bodySmall?.copyWith(
                          color: missed
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                          fontWeight: missed ? FontWeight.w700 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (label != null)
                IconButton(
                  tooltip: 'Open $label',
                  icon: const Icon(Icons.menu_book_rounded),
                  onPressed: () => openMaterial(context, s.link!),
                ),
              PopupMenuButton<String>(
                tooltip: 'More options',
                onSelected: (v) {
                  switch (v) {
                    case 'today':
                      store.replaceSession(
                        s.copyWith(
                          start: _sameTimeOn(s.start, dateOnly(DateTime.now())),
                        ),
                      );
                    case 'tomorrow':
                      store.replaceSession(
                        s.copyWith(
                          start: _sameTimeOn(
                            s.start,
                            addDays(dateOnly(DateTime.now()), 1),
                          ),
                        ),
                      );
                    case 'edit':
                      showSessionEditor(context, existing: s);
                    case 'delete':
                      final messenger = ScaffoldMessenger.of(context);
                      store.removeSession(s.id);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: const Text('Session deleted'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => store.restoreSession(s),
                            ),
                          ),
                        );
                  }
                },
                itemBuilder: (_) => [
                  if (missed)
                    const PopupMenuItem(
                      value: 'today',
                      child: Text('Move to today'),
                    ),
                  const PopupMenuItem(
                    value: 'tomorrow',
                    child: Text('Move to tomorrow'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Reschedule…'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _sameTimeOn(DateTime t, DateTime day) =>
    DateTime(day.year, day.month, day.day, t.hour, t.minute);

/// Small coloured label for how a plan is going.
class PlanStatusChip extends StatelessWidget {
  const PlanStatusChip({super.key, required this.status});

  final PlanStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, bg, fg) = switch (status) {
      PlanStatus.complete => (
        'Complete',
        Icons.check_circle_outline_rounded,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      PlanStatus.behind => (
        'Behind',
        Icons.warning_amber_rounded,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      PlanStatus.onTrack => (
        'On track',
        Icons.trending_up_rounded,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      PlanStatus.past => (
        'Ended',
        Icons.history_rounded,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// A study plan with its progress. Tap to open it.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal});

  final StudyGoal goal;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final course = store.course(goal.courseId);
    final progress = store.planProgress(goal.id);
    final status = store.planStatus(goal.id, now);
    final next = store
        .sessionsFor(goal.id)
        .where((s) => !s.done && !s.end.isBefore(now))
        .firstOrNull;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => GoalScreen(goalId: goal.id)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 8, color: course?.color ?? scheme.secondary),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              goal.title,
                              style: text.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          PlanStatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          ?course?.name,
                          '${daysLeftLabel(goal.target, now: now)} · ${formatShortDate(goal.target)}',
                        ].join(' · '),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: progress.fraction),
                        duration: Motion.of(context, Motion.long2),
                        curve: Motion.emphasized,
                        builder: (context, v, _) =>
                            LinearProgressIndicator(value: v),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progress.count == 0
                            ? 'No sessions yet'
                            : '${progress.doneCount} of ${progress.count} sessions · '
                                  '${formatHours(progress.doneMinutes)} of ${formatHours(progress.plannedMinutes)}',
                        style: text.labelMedium,
                      ),
                      if (next != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Next: ${relativeDay(next.start)}, ${formatTime(context, next.start)}',
                            style: text.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
