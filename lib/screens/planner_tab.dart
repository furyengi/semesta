import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../core/services.dart';
import '../data/store_scope.dart';
import '../theme/motion.dart';
import '../widgets/brutal.dart';
import '../widgets/format.dart';
import '../widgets/plan_sheets.dart';
import '../widgets/study_tiles.dart';
import 'goal_screen.dart';
import 'home_screen.dart' show contentGutter;

/// Opens the plan wizard and, if a plan was made, shows it.
Future<void> startNewPlan(BuildContext context, {PlanTarget? target}) async {
  final goal = await showPlanWizard(context, target: target);
  if (goal != null && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => GoalScreen(goalId: goal.id)),
    );
  }
}

/// The Plan tab: this week at a glance, what needs attention, today's
/// sessions, and every study plan.
class PlannerTab extends StatelessWidget {
  const PlannerTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gutter = contentGutter(context);
    final now = DateTime.now();

    final overdue = store.overdueSessions(now);
    final targets = store.unplannedTargets(now);
    final today = store
        .sessionsOn(now)
        .where((s) => !overdue.contains(s))
        .toList();
    final goals = store.goalsSorted(now);
    final attention = overdue.isNotEmpty || targets.isNotEmpty;

    Widget header(String title, {String? trailing}) => Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: text.titleLarge)),
          if (trailing != null)
            Text(
              trailing,
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 112),
            sliver: SliverList.list(
              children: [
                Text('Study planner', style: text.headlineLarge),
                const SizedBox(height: 4),
                Text(
                  'Break revision into sessions and see what needs attention next.',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                const _WeekSummary(),
                const _ReminderPrompt(),
                if (attention) ...[
                  header('Needs attention'),
                  for (final s in overdue.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SessionTile(session: s, showDate: true),
                    ),
                  if (overdue.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '+ ${overdue.length - 3} more missed sessions',
                        style: text.labelMedium?.copyWith(color: scheme.error),
                      ),
                    ),
                  for (final t in targets.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _UnplannedTile(target: t),
                    ),
                ],
                header('Today', trailing: formatShortDate(now)),
                if (today.isEmpty)
                  Text(
                    store.sessionsOn(now).isEmpty
                        ? 'No study sessions today.'
                        : 'Everything for today is above.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final s in today)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SessionTile(session: s),
                    ),
                header(
                  'Plans',
                  trailing: goals.isEmpty ? null : '${goals.length}',
                ),
                if (goals.isEmpty)
                  const _EmptyPlans()
                else
                  for (var i = 0; i < goals.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Reveal(
                        key: ValueKey(goals[i].id),
                        index: i,
                        child: GoalCard(goal: goals[i]),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final monday = startOfWeek(DateTime.now());
    final minutes = store.studiedMinutesInWeek(monday);
    final (done, total) = store.sessionsInWeek(monday);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THIS WEEK',
              style: text.labelSmall?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatHours(minutes), style: text.headlineMedium),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'studied',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(end: total == 0 ? 0 : done / total),
              duration: Motion.of(context, Motion.long2),
              curve: Motion.emphasized,
              builder: (context, v, _) => LinearProgressIndicator(value: v),
            ),
            const SizedBox(height: 8),
            Text(
              total == 0
                  ? 'No sessions planned this week'
                  : '$done of $total sessions done',
              style: text.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnplannedTile extends StatelessWidget {
  const _UnplannedTile({required this.target});

  final PlanTarget target;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final course = StoreScope.of(context).course(target.courseId);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Icon(
              target.isExam ? Icons.quiz_outlined : Icons.flag_outlined,
              color: scheme.tertiary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.title,
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      '${daysLeftLabel(target.date)} · ${formatShortDate(target.date)}',
                      ?course?.name,
                    ].join(' · '),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'No study plan yet',
                    style: text.labelMedium?.copyWith(color: scheme.tertiary),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => startNewPlan(context, target: target),
              child: const Text('Plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          Text('No study plans yet', style: text.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Make one for an exam or deadline and Semesta will schedule the sessions.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => startNewPlan(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New plan'),
          ),
        ],
      ),
    );
  }
}

/// One-time tip to turn on reminders, shown once there is something to be
/// reminded about.
class _ReminderPrompt extends StatelessWidget {
  const _ReminderPrompt();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final service = ServicesScope.of(context).reminders;
    final show =
        service.supported &&
        !store.reminders.enabled &&
        !store.reminderPromptDismissed &&
        (store.events.isNotEmpty ||
            store.sessions.isNotEmpty ||
            store.assignments.isNotEmpty);
    if (!show) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Never miss a class or session',
                      style: text.titleSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Get a nudge before classes, study sessions and deadlines.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await service.enable();
                      if (!ok) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Notifications are blocked for Semesta. Allow them in your phone\u2019s settings.',
                              ),
                            ),
                          );
                      }
                    },
                    child: const Text('Turn on'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: store.dismissReminderPrompt,
                    child: Text(
                      'Not now',
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
