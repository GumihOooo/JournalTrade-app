import 'package:flutter/material.dart';

import '../gumi_spacing_radius.dart';

/// Shared date+time picker field (DESIGN.md §6 `DateTimeField`, P0-08.11).
/// Label carries the required marker from the parent form.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.requiredMark = false,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool requiredMark;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? now),
    );
    if (time == null) return;

    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value == null
        ? ''
        // Material full-date lacks a time part — append in 24h.
        : '${MaterialLocalizations.of(context).formatFullDate(value!)} '
            '${value!.hour.toString().padLeft(2, '0')}:'
            '${value!.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.all(Radius.circular(GumiRadius.input)),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: requiredMark ? '$label *' : label,
          suffixIcon: const Icon(Icons.event_outlined, size: 20),
          errorText: requiredMark && value == null ? 'Required' : null,
        ),
        child: Text(
          display,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: value == null ? theme.hintColor : null,
          ),
        ),
      ),
    );
  }
}
