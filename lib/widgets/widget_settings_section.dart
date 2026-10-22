import 'package:flutter/material.dart';

import '../core/services.dart';
import '../core/widget_service.dart';
import '../data/widget_data.dart';

/// Messages shown when a widget has nothing to display. Kept in step with
/// `res/values/widget_strings.xml` on Android.
abstract final class WidgetTexts {
  static const emptyNextUp = 'Nothing coming up. Tap to open your calendar.';
  static const emptyToday = 'Nothing planned today.';
  static const emptyDeadlines = 'No deadlines. Nice.';
  static const emptyContinue =
      'Nothing to continue yet. Open a document to start reading.';
}

/// The "Home screen widgets" block of the settings screen: what each widget
/// shows right now, and a button to add it.
class WidgetSettingsSection extends StatelessWidget {
  const WidgetSettingsSection({super.key});

  Future<void> _add(
    BuildContext context,
    WidgetService service,
    WidgetKind kind,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await service.pin(kind);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Confirm in your launcher to place the widget.' : 'Your launcher didn’t accept that. Long-press the home screen and choose Widgets instead.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final service = ServicesScope.of(context).widgets;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.supported) {
          return const ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: false,
            leading: Icon(Icons.widgets_outlined),
            title: Text('Home screen widgets'),
            subtitle: Text('Not available on this platform'),
          );
        }
        final canPin = service.canPin ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              canPin
                  ? 'Put your next class, today’s plan, deadlines or your book on the home screen. '
                        'The previews show what each one displays right now.'
                  : 'Long-press your home screen, choose Widgets, then pick Semesta. '
                        'The previews show what each one displays right now.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final kind in WidgetKind.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(kind.label, style: text.titleSmall),
                        ),
                        if (canPin)
                          Tooltip(
                            message: 'Add ${kind.label.toLowerCase()} widget',
                            child: TextButton.icon(
                              onPressed: () => _add(context, service, kind),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add'),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    WidgetPreview(kind: kind, data: service.data),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A Flutter drawing of what a widget shows from [data] at [now] (defaults
/// to the current time), following the same rules as the Android widgets.
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({
    super.key,
    required this.kind,
    required this.data,
    this.now,
  });

  final WidgetKind kind;
  final Map<String, String> data;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final at = now ?? DateTime.now();
    final nowMs = at.millisecondsSinceEpoch;
    final dim = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final header = text.labelSmall?.copyWith(
      color: scheme.primary,
      letterSpacing: 1.2,
    );

    Widget body;
    String title;
    switch (kind) {
      case WidgetKind.nextUp:
        final e = currentNextUp(data, nowMs);
        final ongoing = e != null && (e['startMs'] as int? ?? 1 << 62) <= nowMs;
        title = ongoing ? 'HAPPENING NOW' : 'NEXT UP';
        body = e == null
            ? Text(WidgetTexts.emptyNextUp, style: dim)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e['title'] as String? ?? '',
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(e['when'] as String? ?? '', style: text.bodySmall),
                  if ((e['subtitle'] as String? ?? '').isNotEmpty)
                    Text(
                      e['subtitle'] as String,
                      style: dim,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              );
      case WidgetKind.today:
        title = 'TODAY';
        final items = todayEntries(data, at);
        body = items.isEmpty
            ? Text(WidgetTexts.emptyToday, style: dim)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final i in items.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 68,
                            child: Text(
                              i['time'] as String? ?? '',
                              style: dim?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              i['title'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium?.copyWith(
                                color: (i['endMs'] as int? ?? 1 << 62) < nowMs
                                    ? scheme.onSurfaceVariant
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (items.length > 5)
                    Text('+${items.length - 5} more', style: dim),
                ],
              );
      case WidgetKind.deadlines:
        title = 'DEADLINES';
        final items = deadlineEntries(data, nowMs);
        body = items.isEmpty
            ? Text(WidgetTexts.emptyDeadlines, style: dim)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final d in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['title'] as String? ?? '',
                            style: text.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [
                              if (d['overdue'] == true) 'Overdue',
                              d['when'] as String? ?? '',
                              if ((d['subtitle'] as String? ?? '').isNotEmpty)
                                d['subtitle'] as String,
                            ].join(' · '),
                            style: dim?.copyWith(
                              color: d['overdue'] == true ? scheme.error : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              );
      case WidgetKind.continueReading:
        title = 'CONTINUE READING';
        final c = continueEntry(data);
        body = c == null
            ? Text(WidgetTexts.emptyContinue, style: dim)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['title'] as String? ?? '',
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(c['subtitle'] as String? ?? '', style: dim),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: ((c['progress'] as int?) ?? 0) / 100,
                  ),
                ],
              );
    }

    return Semantics(
      container: true,
      label: 'Preview of the ${kind.label} widget',
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: header),
                const SizedBox(height: 6),
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
