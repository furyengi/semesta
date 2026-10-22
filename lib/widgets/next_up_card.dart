import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../theme/app_theme.dart';
import '../theme/brutal_theme.dart';
import 'brutal.dart';
import 'format.dart';
import 'material_link.dart';

/// "Next up" on the Library tab: the next class or exam (if it's soon) with
/// a button straight to its linked material, plus the nearest deadline.
class NextUpCard extends StatelessWidget {
  const NextUpCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final next = store.upcoming(now, count: 1).firstOrNull;
    final soon =
        next != null && next.start.difference(now) < const Duration(hours: 36);
    final due = store.openAssignmentsFrom(now, count: 1).firstOrNull;
    final dueSoon =
        due != null && due.due.difference(now) < const Duration(days: 3);
    final study = store
        .sessionsOn(now)
        .where((s) => !s.done && s.end.isAfter(now))
        .toList();
    if (!soon && !dueSoon && study.isEmpty) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = text.labelMedium?.copyWith(color: scheme.onSurfaceVariant);

    Widget content = const SizedBox.shrink();
    if (soon) {
      final e = next.event;
      final course = store.course(e.courseId);
      final label = materialLabel(store, e.link);
      final subtitle = [
        ?course?.name,
        if (e.location.isNotEmpty) e.location,
      ].join(' · ');
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: course?.color ?? scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: BrutalTheme.of(context).border,
                    width: BrutalTheme.of(context).borderWidth,
                  ),
                ),
                child: Icon(
                  e.kind.icon,
                  size: 22,
                  color: AccentPalette.on(
                    course?.color ?? scheme.primaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT UP · ${formatWhen(context, next.start, now: now)}'
                          .toUpperCase(),
                      style: text.labelSmall?.copyWith(color: scheme.primary),
                    ),
                    Text(
                      e.title,
                      style: text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => openMaterial(context, e.link!),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 4),
      child: Reveal(
        child: BrutalBox(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (soon) content,
              if (soon && (study.isNotEmpty || dueSoon))
                const Divider(height: 24),
              if (study.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 20,
                      color: scheme.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${study.length} study ${study.length == 1 ? 'session' : 'sessions'} today · '
                        'next ${formatTime(context, study.first.start)}',
                        style: text.bodyMedium,
                      ),
                    ),
                    if (study.first.link != null)
                      IconButton(
                        tooltip:
                            'Open ${materialLabel(store, study.first.link) ?? 'material'}',
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () =>
                            openMaterial(context, study.first.link!),
                      ),
                  ],
                ),
              if (study.isNotEmpty && dueSoon) const Divider(height: 24),
              if (dueSoon)
                Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 20, color: scheme.tertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${due.title} · due ${formatWhen(context, due.due, now: now)}',
                        style: text.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
