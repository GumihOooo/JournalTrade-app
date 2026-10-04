import 'package:flutter/material.dart';

import '../gumi_spacing_radius.dart';

/// Select field: opens bottom sheet with options (DESIGN.md §6: `SelectField`).
class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value == null ? (hint ?? '') : _itemLabel(value);

    return InkWell(
      onTap: enabled ? () => _openSheet(context) : null,
      borderRadius: BorderRadius.all(Radius.circular(GumiRadius.input)),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Text(
          display,
          style: value == null
              ? theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)
              : theme.textTheme.bodyMedium,
        ),
      ),
    );
  }

  String _itemLabel(T? item) => item is Enum
      ? item.name
      : item is String
          ? item
          : item.toString();

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GumiRadius.glass)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(GumiSpacings.lg),
              child: Text(label, style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text(_itemLabel(item)),
                      trailing: item == value ? const Icon(Icons.check, size: 20) : null,
                      onTap: () => Navigator.pop(sheetContext, item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) onChanged(result);
  }
}

/// Tag selector: multi-select chips (DESIGN.md §6: `TagSelector`).
class TagSelector<T> extends StatelessWidget {
  const TagSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
  });

  final String label;
  final List<T> options;
  final List<T> selected;
  final ValueChanged<T> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: GumiSpacings.sm),
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
        Wrap(
          spacing: GumiSpacings.sm,
          runSpacing: GumiSpacings.sm,
          children: [
            for (final option in options)
              _Tag(
                label: option is Enum
                    ? option.name
                    : option is String
                        ? option
                        : option.toString(),
                selected: selected.contains(option),
                enabled: enabled,
                onTap: () => onToggle(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.selected, required this.onTap, this.enabled = true});

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected ? scheme.primary : scheme.surface,
      borderRadius: BorderRadius.all(Radius.circular(GumiRadius.control)),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.all(Radius.circular(GumiRadius.control)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(GumiRadius.control)),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter chip for Journal filters (DESIGN.md §6: `FilterChip`).
class GumiFilterChip<T> extends StatelessWidget {
  const GumiFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary,
      side: BorderSide(color: selected ? scheme.primary : scheme.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(GumiRadius.control)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }
}
