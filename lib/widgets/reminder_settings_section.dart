import 'package:flutter/material.dart';

import '../core/reminder_service.dart';
import '../core/services.dart';
import '../data/reminder_settings.dart';
import '../data/store_scope.dart';
import '../theme/motion.dart';
import 'format.dart';
import 'pickers.dart';

String _minutesLabel(int m) => m < 60 ? '$m min' : '${m ~/ 60} h';
String _hoursLabel(int h) =>
    h < 24 ? '$h h' : (h == 24 ? '1 day' : '${h ~/ 24} days');

/// The Reminders block of the settings screen.
class ReminderSettingsSection extends StatelessWidget {
  const ReminderSettingsSection({super.key});

  Future<void> _toggleMaster(
    BuildContext context,
    ReminderService service,
    bool on,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!on) {
      service.disable();
      return;
    }
    final granted = await service.enable();
    if (!granted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are blocked for Semesta. Allow them in your phone’s settings.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ServicesScope.of(context).reminders;
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.supported) {
          return const ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: false,
            leading: Icon(Icons.notifications_off_outlined),
            title: Text('Reminders'),
            subtitle: Text('Not available on this platform'),
          );
        }
        final r = store.reminders;
        void set(ReminderSettings s) => store.reminders = s;
        final blocked = r.enabled && service.permissionGranted == false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Reminders'),
              subtitle: const Text(
                'Before classes, study sessions and deadlines',
              ),
              value: r.enabled,
              onChanged: (v) => _toggleMaster(context, service, v),
            ),
            AnimatedSize(
              duration: Motion.of(context, Motion.medium2),
              curve: Motion.emphasized,
              alignment: Alignment.topCenter,
              child: !r.enabled
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (blocked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: scheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Notifications are blocked for Semesta, so nothing will be delivered. '
                                        'Allow them in your phone’s settings.',
                                        style: text.bodySmall?.copyWith(
                                          color: scheme.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        _ReminderOption(
                          title: 'Classes',
                          value: r.classes,
                          onChanged: (v) => set(r.copyWith(classes: v)),
                          choices: ReminderSettings.classLeadChoices,
                          selected: r.classLeadMin,
                          label: (m) => '${_minutesLabel(m)} before',
                          onSelected: (m) => set(r.copyWith(classLeadMin: m)),
                        ),
                        _ReminderOption(
                          title: 'Exams',
                          value: r.exams,
                          onChanged: (v) => set(r.copyWith(exams: v)),
                          choices: ReminderSettings.hoursLeadChoices,
                          selected: r.examLeadHours,
                          label: (h) => '${_hoursLabel(h)} before',
                          onSelected: (h) => set(r.copyWith(examLeadHours: h)),
                        ),
                        _ReminderOption(
                          title: 'Study sessions',
                          value: r.study,
                          onChanged: (v) => set(r.copyWith(study: v)),
                          choices: ReminderSettings.studyLeadChoices,
                          selected: r.studyLeadMin,
                          label: (m) => '${_minutesLabel(m)} before',
                          onSelected: (m) => set(r.copyWith(studyLeadMin: m)),
                        ),
                        _ReminderOption(
                          title: 'Deadlines',
                          value: r.deadlines,
                          onChanged: (v) => set(r.copyWith(deadlines: v)),
                          choices: ReminderSettings.hoursLeadChoices,
                          selected: r.deadlineLeadHours,
                          label: (h) => '${_hoursLabel(h)} before',
                          onSelected: (h) =>
                              set(r.copyWith(deadlineLeadHours: h)),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Daily summary'),
                          subtitle: const Text('A morning look at your day'),
                          value: r.digest,
                          onChanged: (v) => set(r.copyWith(digest: v)),
                        ),
                        if (r.digest)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TimePickerButton(
                              value: DateTime(
                                2000,
                                1,
                                1,
                                r.digestMinute ~/ 60,
                                r.digestMinute % 60,
                              ),
                              onChanged: (t) => set(
                                r.copyWith(
                                  digestMinute: t.hour * 60 + t.minute,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          service.scheduled.isEmpty
                              ? 'Nothing to remind you about yet.'
                              : '${service.scheduled.length} reminders scheduled · next: '
                                    '${formatWhen(context, service.scheduled.first.when)}',
                          style: text.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reminders can arrive a few minutes late when your phone is saving battery. '
                          'They refresh whenever you open Semesta.',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: service.sendTest,
                          icon: const Icon(Icons.notifications_none_rounded),
                          label: const Text('Send a test notification'),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// A reminder type: on/off switch, and how far ahead when on.
class _ReminderOption extends StatelessWidget {
  const _ReminderOption({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.choices,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final List<int> choices;
  final int selected;
  final String Function(int) label;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          value: value,
          onChanged: onChanged,
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium2),
          curve: Motion.emphasized,
          alignment: Alignment.topCenter,
          child: !value
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in choices)
                        ChoiceChip(
                          label: Text(label(c)),
                          selected: selected == c,
                          onSelected: (_) => onSelected(c),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
