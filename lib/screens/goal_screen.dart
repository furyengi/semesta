import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../data/store_scope.dart';
import '../theme/motion.dart';
import '../widgets/brutal.dart';
import '../widgets/format.dart';
import '../widgets/material_link.dart';
import '../widgets/plan_sheets.dart';
import '../widgets/study_tiles.dart';
import 'home_screen.dart' show contentGutter;

enum _GoalMenu { replan, date, rename, delete }

/// One study plan: progress and every session, grouped by day.
class GoalScreen extends StatelessWidget {
  const GoalScreen({super.key, required this.goalId});

  final String goalId;

  Future<void> _replan(BuildContext context, StudyGoal g) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final left = g.totalMinutes - store.planProgress(g.id).doneMinutes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.autorenew_rounded),
        title: const Text('Re-plan what’s left?'),
        content: Text(
          left <= 0
              ? 'You’ve already covered the planned time.'
              : 'Sessions still to do will be removed and ${formatHours(left)} of study '
                    'will be spread over the days before ${formatShortDate(g.target)}. '
                    'Finished sessions stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Re-plan'),
          ),
        ],
      ),
    );
    if (ok == true) {
      store.replanGoal(g.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Plan updated')));
    }
  }

  Future<void> _changeDate(BuildContext context, StudyGoal g) async {
    final store = StoreScope.read(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: g.target,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      store.replanGoal(
        g.id,
        newTarget: DateTime(
          picked.year,
          picked.month,
          picked.day,
          g.target.hour,
          g.target.minute,
        ),
      );
    }
  }

  Future<void> _rename(BuildContext context, StudyGoal g) async {
    final store = StoreScope.read(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: g.title),
    );
    if (name != null) store.updateGoal(g.id, title: name);
  }

  Future<void> _delete(BuildContext context, StudyGoal g) async {
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text('Delete "${g.title}"?'),
        content: const Text(
          'The plan and all of its sessions will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      nav.pop();
      store.removeGoal(g.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.goal(goalId);
    if (g == null) return const Scaffold(body: SizedBox.shrink());

    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gutter = contentGutter(context);
    final now = DateTime.now();
    final sessions = store.sessionsFor(g.id);
    final progress = store.planProgress(g.id);
    final status = store.planStatus(g.id, now);
    final course = store.course(g.courseId);
    final doc = g.docId == null ? null : store.doc(g.docId!);

    // Group by day.
    final byDay = <DateTime, List<StudySession>>{};
    for (final s in sessions) {
      byDay.putIfAbsent(dateOnly(s.start), () => []).add(s);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              PopupMenuButton<_GoalMenu>(
                tooltip: 'More options',
                onSelected: (m) {
                  switch (m) {
                    case _GoalMenu.replan:
                      _replan(context, g);
                    case _GoalMenu.date:
                      _changeDate(context, g);
                    case _GoalMenu.rename:
                      _rename(context, g);
                    case _GoalMenu.delete:
                      _delete(context, g);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _GoalMenu.replan,
                    child: Text('Re-plan remaining'),
                  ),
                  PopupMenuItem(
                    value: _GoalMenu.date,
                    child: Text('Change date'),
                  ),
                  PopupMenuItem(value: _GoalMenu.rename, child: Text('Rename')),
                  PopupMenuItem(
                    value: _GoalMenu.delete,
                    child: Text('Delete plan'),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 48),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    PlanStatusChip(status: status),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        [
                          ?course?.name,
                          '${daysLeftLabel(g.target, now: now)} · ${formatShortDate(g.target)}',
                        ].join(' · '),
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DecoratedBox(
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
                          formatHours(progress.doneMinutes),
                          style: text.headlineMedium,
                        ),
                        Text(
                          'of ${formatHours(progress.plannedMinutes)} planned',
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
                          '${progress.doneCount} of ${progress.count} sessions done',
                          style: text.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                if (doc != null &&
                    g.firstPage != null &&
                    g.lastPage != null) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_rounded),
                    title: Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('Pages ${g.firstPage}–${g.lastPage}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => openMaterial(
                      context,
                      MaterialLink(docId: doc.id, page: g.firstPage),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Text('Sessions', style: text.titleLarge)),
                    TextButton.icon(
                      onPressed: () => showSessionEditor(context, goalId: g.id),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No sessions fit before this date. Change the date, or add sessions yourself.',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final entry in byDay.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                    child: Text(
                      relativeDay(entry.key, now: now) ==
                              formatShortDate(entry.key)
                          ? formatShortDate(entry.key)
                          : '${relativeDay(entry.key, now: now)} · ${formatShortDate(entry.key)}',
                      style: text.titleSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final s in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Reveal(
                        child: SessionTile(key: ValueKey(s.id), session: s),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename plan'),
    content: TextField(
      controller: _c,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _c.text),
        child: const Text('Save'),
      ),
    ],
  );
}
