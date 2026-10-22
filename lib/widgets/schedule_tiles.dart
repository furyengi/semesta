import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../data/store_scope.dart';
import '../theme/motion.dart';
import 'course_sheets.dart';
import 'event_sheets.dart';
import 'format.dart';
import 'material_link.dart';

/// One timetable entry in a list. Tap for details; the book button jumps to
/// the linked material.
class OccurrenceTile extends StatelessWidget {
  const OccurrenceTile({
    super.key,
    required this.occurrence,
    this.showDate = false,
  });

  final Occurrence occurrence;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final e = occurrence.event;
    final course = store.course(e.courseId);
    final color = course?.color ?? scheme.primary;
    final label = materialLabel(store, e.link);
    final subtitle = [
      ?course?.name,
      if (e.location.isNotEmpty) e.location,
    ].join(' · ');

    return Semantics(
      container: true,
      label:
          '${e.kind.label}, ${e.title}, ${formatTimeRange(context, occurrence.start, occurrence.end)}',
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showEventDetails(context, occurrence),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            if (showDate) formatShortDate(occurrence.start),
                            formatTimeRange(
                              context,
                              occurrence.start,
                              occurrence.end,
                            ),
                          ].join(' · '),
                          style: text.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(e.kind.icon, size: 16, color: color),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.title,
                                style: text.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (label != null)
                  IconButton(
                    tooltip: 'Open $label',
                    icon: const Icon(Icons.menu_book_rounded),
                    onPressed: () => openMaterial(context, e.link!),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An assignment with a checkbox. Tap the row to edit.
class AssignmentTile extends StatelessWidget {
  const AssignmentTile({
    super.key,
    required this.assignment,
    this.showCourse = false,
  });

  final Assignment assignment;
  final bool showCourse;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = assignment;
    final course = store.course(a.courseId);
    final overdue = !a.done && a.due.isBefore(DateTime.now());
    final label = materialLabel(store, a.link);
    final subtitle = [
      'Due ${formatWhen(context, a.due)}',
      if (showCourse) ?course?.name,
    ].join(' · ');

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            showAssignmentEditor(context, courseId: a.courseId, existing: a),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            children: [
              Checkbox(
                value: a.done,
                shape: const CircleBorder(),
                onChanged: (_) => store.toggleAssignment(a.id),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: Motion.of(context, Motion.short4),
                        style: (text.titleSmall ?? const TextStyle()).copyWith(
                          decoration: a.done
                              ? TextDecoration.lineThrough
                              : null,
                          color: a.done
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                        child: Text(
                          a.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: overdue
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                          fontWeight: overdue ? FontWeight.w700 : null,
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
                  onPressed: () => openMaterial(context, a.link!),
                ),
              PopupMenuButton<String>(
                tooltip: 'More options',
                onSelected: (v) {
                  if (v == 'edit') {
                    showAssignmentEditor(
                      context,
                      courseId: a.courseId,
                      existing: a,
                    );
                  } else {
                    final messenger = ScaffoldMessenger.of(context);
                    store.removeAssignment(a.id);
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: const Text('Assignment deleted'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => store.replaceAssignmentOrAdd(a),
                          ),
                        ),
                      );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
