import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/gumi.dart';
import 'calculator_specs.dart';

/// P2-01.02..11 Generic calculator screen: input fields + live result,
/// copy action (P2-01.12). Ephemeral by design — results live in
/// widget state only and are never written anywhere.
class CalculatorDetailScreen extends StatefulWidget {
  const CalculatorDetailScreen({super.key, required this.spec});

  final CalculatorSpec spec;

  @override
  State<CalculatorDetailScreen> createState() => _CalculatorDetailScreenState();
}

class _CalculatorDetailScreenState extends State<CalculatorDetailScreen> {
  late final Map<String, TextEditingController> _controllers;
  bool _isBuy = true;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final f in widget.spec.fields)
        if (f.type == CalcFieldType.number) f.key: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, double?> get _inputs => {
        for (final e in _controllers.entries)
          e.key: double.tryParse(e.value.text.replaceAll(',', '.')),
      };

  List<CalcResult> get _results => widget.spec.compute(_inputs, _isBuy);

  void _copy(CalcResult r) {
    Clipboard.setData(
      ClipboardData(text: '${r.label}: ${formatCalcResult(r)}'),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Copied to clipboard.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    final results = _results;

    return Scaffold(
      backgroundColor: c.bgPrimary,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/app/settings'),
        ),
        title: Text(widget.spec.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(GumiSpacings.md),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(GumiSpacings.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final f in widget.spec.fields) ...[
                  if (f.type == CalcFieldType.direction)
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Buy')),
                        ButtonSegment(value: false, label: Text('Sell')),
                      ],
                      selected: {_isBuy},
                      onSelectionChanged: (s) =>
                          setState(() => _isBuy = s.first),
                    )
                  else
                    NumericField(
                      key: ValueKey('${widget.spec.id}-${f.key}'),
                      label: f.label,
                      controller: _controllers[f.key],
                      hint: f.hint,
                      suffixText: f.suffix,
                      onChanged: (_) => setState(() {}),
                    ),
                  const SizedBox(height: GumiSpacings.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: GumiSpacings.md),
          GlassCard(
            padding: const EdgeInsets.all(GumiSpacings.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in results) _resultRow(context, r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(BuildContext context, CalcResult r) {
    final c = context.gumiColors;
    final text = formatCalcResult(r);
    final isLoss = r.value != null && r.value! < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GumiSpacings.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(r.label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            text,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isLoss ? c.semanticLoss : c.textPrimary,
                ),
          ),
          IconButton(
            tooltip: 'Copy ${r.label}',
            icon: const Icon(Icons.copy_outlined, size: 18),
            color: c.textMuted,
            onPressed: () => _copy(r),
          ),
        ],
      ),
    );
  }
}
