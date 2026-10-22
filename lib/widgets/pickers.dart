import 'package:flutter/material.dart';

import 'format.dart';

/// Outlined button showing a date; opens the Material date picker.
class DatePickerButton extends StatelessWidget {
  const DatePickerButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(
        '${label == null ? '' : '$label '}${formatShortDate(value)} ${value.year}',
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged(
            DateTime(
              picked.year,
              picked.month,
              picked.day,
              value.hour,
              value.minute,
            ),
          );
        }
      },
    );
  }
}

/// Outlined button showing a time; opens the Material time picker.
class TimePickerButton extends StatelessWidget {
  const TimePickerButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.schedule_rounded, size: 18),
      label: Text(formatTime(context, value)),
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (picked != null) {
          onChanged(dateWithTime(value, picked));
        }
      },
    );
  }
}

DateTime dateWithTime(DateTime day, TimeOfDay t) =>
    DateTime(day.year, day.month, day.day, t.hour, t.minute);
