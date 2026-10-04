/// P2-01 calculator definitions (DESIGN.md §5.16): ten standalone
/// calculators, each a field list + pure formula call. Results are
/// never saved — the detail screen holds only ephemeral text.
library;

import 'package:flutter/material.dart';

import 'calculator_formulas.dart';

enum CalcFieldType { number, direction }

class CalcField {
  const CalcField(
    this.key,
    this.label, {
    this.suffix,
    this.type = CalcFieldType.number,
    this.hint,
  });

  final String key;
  final String label;
  final String? suffix;
  final CalcFieldType type;
  final String? hint;
}

class CalcResult {
  const CalcResult(this.label, this.value, {this.suffix});

  final String label;
  final double? value;
  final String? suffix;

  bool get isMoney => suffix == r'$';
}

class CalculatorSpec {
  const CalculatorSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.fields,
    required this.compute,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<CalcField> fields;
  final List<CalcResult> Function(Map<String, double?> inputs, bool isBuy)
      compute;

  /// `null` value means "incomplete input" — renders as —.
  CalcResult? result(Map<String, double?> inputs, String key) {
    for (final r in compute(inputs, inputs['isBuy'] == 1)) {
      if (r.label == key) return r;
    }
    return null;
  }
}

const _pct = '%';

final List<CalculatorSpec> calculatorSpecs = [
  CalculatorSpec(
    id: 'lot-size',
    title: 'Lot Size',
    description: 'How many lots to risk a set amount',
    icon: Icons.scale_outlined,
    fields: [
      const CalcField('balance', 'Account Balance', suffix: r'$'),
      const CalcField('riskPercent', 'Risk', suffix: _pct),
      const CalcField('stopDistance', 'Stop Loss Distance', suffix: 'price'),
    ],
    compute: (i, _) => [
      CalcResult(
          'Lot Size',
          lotSize(
            balance: i['balance'],
            riskPercent: i['riskPercent'],
            stopDistance: i['stopDistance'],
          ),
          suffix: 'lots'),
    ],
  ),
  CalculatorSpec(
    id: 'position-size',
    title: 'Position Size',
    description: 'Units behind a number of lots',
    icon: Icons.linear_scale_outlined,
    fields: [
      const CalcField('lots', 'Lot Size', suffix: 'lots'),
      const CalcField('contractSize', 'Contract Size', suffix: 'units/lot'),
    ],
    compute: (i, _) => [
      CalcResult('Position Size',
          positionSize(lots: i['lots'], contractSize: i['contractSize']),
          suffix: 'units'),
    ],
  ),
  CalculatorSpec(
    id: 'risk',
    title: 'Risk',
    description: 'Money at risk for a stop distance',
    icon: Icons.warning_amber_outlined,
    fields: [
      const CalcField('stopDistance', 'Stop Loss Distance', suffix: 'pips'),
      const CalcField('lots', 'Lot Size', suffix: 'lots'),
      const CalcField('pipValuePerLot', 'Pip Value per Lot', suffix: r'$/pip'),
    ],
    compute: (i, _) => [
      CalcResult(
          'Risk',
          riskMoney(
            stopDistance: i['stopDistance'],
            lots: i['lots'],
            pipValuePerLot: i['pipValuePerLot'],
          ),
          suffix: r'$'),
    ],
  ),
  CalculatorSpec(
    id: 'risk-percent',
    title: 'Risk %',
    description: 'Risk as a share of balance',
    icon: Icons.percent_outlined,
    fields: [
      const CalcField('riskMoney', 'Risk Amount', suffix: r'$'),
      const CalcField('balance', 'Account Balance', suffix: r'$'),
    ],
    compute: (i, _) => [
      CalcResult(
          'Risk',
          riskPercent(riskMoney: i['riskMoney'], balance: i['balance']),
          suffix: _pct),
    ],
  ),
  CalculatorSpec(
    id: 'pip-value',
    title: 'Pip Value',
    description: 'Value of one pip for the position',
    icon: Icons.water_drop_outlined,
    fields: [
      const CalcField('pipDistance', 'Pip Size', suffix: 'price'),
      const CalcField('contractSize', 'Contract Size', suffix: 'units/lot'),
      const CalcField('lots', 'Lot Size', suffix: 'lots'),
    ],
    compute: (i, _) => [
      CalcResult(
          'Pip Value',
          pipValue(
            pipDistance: i['pipDistance'],
            contractSize: i['contractSize'],
            lots: i['lots'],
          ),
          suffix: r'$'),
    ],
  ),
  CalculatorSpec(
    id: 'margin',
    title: 'Margin',
    description: 'Capital required to open the position',
    icon: Icons.account_balance_wallet_outlined,
    fields: [
      const CalcField('price', 'Entry Price'),
      const CalcField('lots', 'Lot Size', suffix: 'lots'),
      const CalcField('contractSize', 'Contract Size', suffix: 'units/lot'),
      const CalcField('leverage', 'Leverage', suffix: 'x'),
    ],
    compute: (i, _) => [
      CalcResult(
          'Margin',
          margin(
            price: i['price'],
            lots: i['lots'],
            contractSize: i['contractSize'],
            leverage: i['leverage'],
          ),
          suffix: r'$'),
    ],
  ),
  CalculatorSpec(
    id: 'profit',
    title: 'Profit',
    description: 'P/L for entry, exit and size',
    icon: Icons.trending_up_outlined,
    fields: [
      const CalcField('direction', 'Direction', type: CalcFieldType.direction),
      const CalcField('entry', 'Entry Price'),
      const CalcField('exit', 'Exit Price'),
      const CalcField('contractSize', 'Contract Size', suffix: 'units/lot'),
      const CalcField('lots', 'Lot Size', suffix: 'lots'),
    ],
    compute: (i, isBuy) => [
      CalcResult(
          'Profit',
          profit(
            entry: i['entry'],
            exit: i['exit'],
            contractSize: i['contractSize'],
            lots: i['lots'],
            isBuy: isBuy,
          ),
          suffix: r'$'),
    ],
  ),
  CalculatorSpec(
    id: 'drawdown',
    title: 'Drawdown',
    description: 'Decline from peak balance',
    icon: Icons.south_outlined,
    fields: [
      const CalcField('peak', 'Peak Balance', suffix: r'$'),
      const CalcField('current', 'Current Balance', suffix: r'$'),
    ],
    compute: (i, _) => [
      CalcResult('Drawdown',
          drawdown(peak: i['peak'], current: i['current']), suffix: r'$'),
      CalcResult('Drawdown %',
          drawdownPercent(peak: i['peak'], current: i['current']),
          suffix: _pct),
    ],
  ),
  CalculatorSpec(
    id: 'compound',
    title: 'Compound',
    description: 'Balance after repeated gains',
    icon: Icons.auto_graph_outlined,
    fields: [
      const CalcField('balance', 'Starting Balance', suffix: r'$'),
      const CalcField('gainPercent', 'Gain per Period', suffix: _pct),
      const CalcField('periods', 'Periods', suffix: 'x'),
    ],
    compute: (i, _) => [
      CalcResult(
          'Final Balance',
          compound(
            balance: i['balance'],
            gainPercent: i['gainPercent'],
            periods: i['periods'],
          ),
          suffix: r'$'),
    ],
  ),
  CalculatorSpec(
    id: 'risk-reward',
    title: 'Risk/Reward',
    description: 'Reward distance vs risk distance',
    icon: Icons.balance_outlined,
    fields: [
      const CalcField('entry', 'Entry Price'),
      const CalcField('stopLoss', 'Stop Loss'),
      const CalcField('takeProfit', 'Take Profit'),
    ],
    compute: (i, _) => [
      CalcResult(
          'R:R',
          riskReward(
            entry: i['entry'],
            stopLoss: i['stopLoss'],
            takeProfit: i['takeProfit'],
          ),
          suffix: 'R'),
    ],
  ),
];

/// Formats a result: integers without decimals, else up to 4
/// decimals with trailing zeros stripped. `null` → '—'.
String formatCalcValue(double? v) {
  if (v == null) return '—';
  if (v == v.roundToDouble() && v.abs() < 1e15) {
    return v.toStringAsFixed(0);
  }
  // Trim to 4 decimals max, then strip trailing zeros (0.0450 → 0.045).
  var s = v.toStringAsFixed(4);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

/// Formats a full result row: value + suffix. Money renders as
/// `$1,234` / `-$50` (sign before symbol); others as `2.5 %`.
String formatCalcResult(CalcResult r) {
  final raw = formatCalcValue(r.value);
  if (r.suffix == r'$') {
    return '${raw.startsWith('-') ? '-' : ''}\$${raw.replaceFirst('-', '')}';
  }
  return r.suffix == null ? raw : '$raw ${r.suffix}';
}
