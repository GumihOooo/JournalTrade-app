import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/appwrite/appwrite_failure_mapper.dart';
import '../../core/constants/instrument_contract_specs.dart';
import '../../core/design/gumi.dart';
import '../../core/errors/failure.dart';
import '../settings/user_settings_provider.dart';
import 'add_trade_controller.dart';
import 'domain/trade.dart';
import 'trade_detail_controller.dart';

/// Manual Add Trade form (P0-08.02..05, DESIGN.md §5.7).
///
/// Sections wrapped in separate GlassCards with clear spacing —
/// backdrop-blur glass (not liquid glass) because the content scrolls
/// (DESIGN.md §3.2).
///
/// Reusable for OCR review (P1-04/P1-05): [initialDraft] pre-fills every
/// detected field and flips [inputMethod] to `ocr`; the user reviews,
/// edits, and confirms before save — the same form, never a duplicate.
class AddTradeScreen extends ConsumerStatefulWidget {
  const AddTradeScreen({super.key, this.initialDraft, this.editing});

  /// Pre-filled draft (OCR extraction result). Null = empty manual form.
  final TradeDraft? initialDraft;

  /// Edit mode (P0-10.05): the existing trade being edited. Saves run
  /// update instead of create and return to the detail screen.
  final Trade? editing;

  @override
  ConsumerState<AddTradeScreen> createState() => _AddTradeScreenState();
}

class _AddTradeScreenState extends ConsumerState<AddTradeScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TradeInputMethod _inputMethod;
  late final TextEditingController _instrument;
  late final TextEditingController _entry;
  late final TextEditingController _exit;
  late final TextEditingController _stopLoss;
  late final TextEditingController _takeProfit;
  late final TextEditingController _lotSize;
  late final TextEditingController _profitLoss;
  late final TextEditingController _riskReward;
  late final TextEditingController _strategy;
  late final TextEditingController _confluence;
  late final TextEditingController _emotion;
  late final TextEditingController _lesson;
  late final TextEditingController _notes;
  late final TextEditingController _mistakeTags;

  TradeDirection? _direction;
  TradeAccountType _accountType = TradeAccountType.real;
  String? _session;
  DateTime? _openTime;
  DateTime? _closeTime;

  bool _saving = false;

  // Auto-calc ownership (P0-08): auto-fill stops the moment the user
  // edits the field directly; the value always stays editable.
  bool _plTouched = false;
  bool _rrTouched = false;

  /// True while _recalcAuto writes controller text programmatically —
  /// onChanged must not treat those writes as user edits, or the
  /// first auto-fill would lock the field forever.
  bool _writingAuto = false;

  @override
  void initState() {
    super.initState();
    // Edit mode reuses the same pre-fill path: an existing trade is
    // just a draft with an id (P0-10.05 — no duplicate form).
    final d = widget.initialDraft ?? widget.editing?.toDraft();
    // OCR pre-fill (P1-05.02): unread fields arrive as the adapter's
    // zero/epoch sentinels and must render EMPTY for manual entry —
    // never as fake 0 prices or a 1970 timestamp.
    final ocr = d != null &&
        widget.editing == null &&
        d.inputMethod == TradeInputMethod.ocr;
    _inputMethod = d?.inputMethod ?? TradeInputMethod.manual;
    _instrument = TextEditingController(text: d?.instrument ?? '');
    _entry = TextEditingController(
        text: ocr && d.entryPrice == 0 ? '' : _fmt(d?.entryPrice));
    _exit = TextEditingController(
        text: ocr && d.exitPrice == 0 ? '' : _fmt(d?.exitPrice));
    _stopLoss = TextEditingController(text: _fmt(d?.stopLoss));
    _takeProfit = TextEditingController(text: _fmt(d?.takeProfit));
    _lotSize = TextEditingController(
        text: ocr && d.lotSize == 0 ? '' : _fmt(d?.lotSize));
    _profitLoss = TextEditingController(
        text: ocr && d.profitLoss == 0 ? '' : _fmt(d?.profitLoss));
    _riskReward = TextEditingController(text: _fmt(d?.riskReward));
    _strategy = TextEditingController(text: d?.strategy ?? '');
    _confluence =
        TextEditingController(text: (d?.confluence ?? const []).join(', '));
    _emotion = TextEditingController(text: d?.emotion ?? '');
    _lesson = TextEditingController(text: d?.lessonLearned ?? '');
    _notes = TextEditingController(text: d?.notes ?? '');
    _direction = d?.direction ?? TradeDirection.buy;
    _accountType = d?.accountType ?? TradeAccountType.real;
    _session = d?.session;
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    _openTime = ocr && d.openTime == epoch ? null : d?.openTime;
    _closeTime = ocr && d.closeTime == epoch ? null : d?.closeTime;
    _mistakeTags =
        TextEditingController(text: (d?.mistakeTags ?? const []).join(', '));

    // A pre-filled draft (OCR/edit): start untouched so active user edits to price/lot
    // trigger live recalculation. Only explicitly set to touched if user directly edits P/L or RR.
    _plTouched = false;
    _rrTouched = false;

    // Live auto-calc while the user types prices (P0-08).
    for (final c in [_instrument, _entry, _exit, _stopLoss, _lotSize]) {
      c.addListener(_recalcAuto);
    }
  }

  void _recalcAuto() {
    if (!mounted || _saving) return;
    // Direction always has a value (defaults to buy), so the P/L sign
    // is never a guess — the user sees the sign flip when toggling.
    final pl = autoProfitLoss(
      instrument: _instrument.text,
      isBuy: _direction == TradeDirection.buy,
      entry: double.tryParse(_entry.text),
      exit: double.tryParse(_exit.text),
      lotSize: double.tryParse(_lotSize.text),
    );
    final rr = autoRiskReward(
      entry: double.tryParse(_entry.text),
      exit: double.tryParse(_exit.text),
      stopLoss: double.tryParse(_stopLoss.text),
    );
    // Writing controller.text does not need setState — the fields
    // rebuild themselves from the controller.
    _writingAuto = true;
    try {
      if (!_plTouched && pl != null) _profitLoss.text = _trimNum(pl);
      if (!_rrTouched && rr != null) _riskReward.text = _trimNum(rr);
    } finally {
      _writingAuto = false;
    }
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  static String? _fmt(double? v) => v == null ? '' : v.toString();

  @override
  void dispose() {
    for (final c in [
      _instrument,
      _entry,
      _exit,
      _stopLoss,
      _takeProfit,
      _lotSize,
      _profitLoss,
      _riskReward,
      _strategy,
      _confluence,
      _emotion,
      _lesson,
      _notes,
      _mistakeTags,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_direction == null) {
      _snack('Direction is required.');
      return;
    }
    if (_openTime == null || _closeTime == null) {
      _snack('Open and close times are required.');
      return;
    }
    if (_closeTime!.isBefore(_openTime!)) {
      _snack('Close time must not be before open time.');
      return;
    }

    setState(() => _saving = true); // P0-08.13: no double submit.
    final draft = TradeDraft(
      instrument: _instrument.text.trim(),
      direction: _direction!,
      accountType: _accountType,
      entryPrice: double.parse(_entry.text),
      exitPrice: double.parse(_exit.text),
      stopLoss: _stopLoss.text.isEmpty ? null : double.parse(_stopLoss.text),
      takeProfit:
          _takeProfit.text.isEmpty ? null : double.parse(_takeProfit.text),
      lotSize: double.parse(_lotSize.text),
      profitLoss: double.parse(_profitLoss.text),
      riskReward:
          _riskReward.text.isEmpty ? null : double.parse(_riskReward.text),
      openTime: _openTime!,
      closeTime: _closeTime!,
      strategy: _strategy.text.isEmpty ? null : _strategy.text.trim(),
      session: _session,
      confluence: _splitTags(_confluence.text),
      emotion: _emotion.text.isEmpty ? null : _emotion.text.trim(),
      mistakeTags: _splitTags(_mistakeTags.text),
      lessonLearned: _lesson.text.isEmpty ? null : _lesson.text,
      notes: _notes.text.isEmpty ? null : _notes.text,
      inputMethod: _inputMethod,
    );
    try {
      if (widget.editing != null) {
        // P0-10.06: update path — same form, different call.
        await ref.read(tradeDetailControllerProvider.notifier).updateTrade(
              widget.editing!.copyWith(
                instrument: draft.instrument,
                direction: draft.direction,
                accountType: draft.accountType,
                entryPrice: draft.entryPrice,
                exitPrice: draft.exitPrice,
                stopLoss: draft.stopLoss,
                takeProfit: draft.takeProfit,
                lotSize: draft.lotSize,
                profitLoss: draft.profitLoss,
                riskReward: draft.riskReward,
                openTime: draft.openTime,
                closeTime: draft.closeTime,
                strategy: draft.strategy,
                session: draft.session,
                confluence: draft.confluence,
                emotion: draft.emotion,
                mistakeTags: draft.mistakeTags,
                lessonLearned: draft.lessonLearned,
                notes: draft.notes,
              ),
            );
        if (mounted) {
          _snack('Trade updated.');
          context.pop();
        }
        return;
      }
      await ref.read(addTradeControllerProvider.notifier).save(draft);
      if (mounted) {
        _snack('Trade saved.');
        context.go('/app/journal');
      }
    } on Failure catch (e) {
      if (mounted) _snack(e.message);
    } on AppwriteException catch (e) {
      if (mounted) _snack(AppwriteFailureMapper.map(e).message);
    } catch (_) {
      if (mounted) _snack('Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _splitTags(String raw) => raw
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  String get _appTitle {
    if (widget.editing != null) return 'Edit Trade';
    return _inputMethod == TradeInputMethod.ocr
        ? 'Review Extracted Trade'
        : 'Add Trade';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    // S-5: P/L currency follows the profile's balanceCurrency.
    final currency = ref.watch(balanceCurrencyProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/app/dashboard')),
        title: Text(_appTitle),
      ),
      backgroundColor: c.bgPrimary,
      body: Form(
        key: _formKey,
        child: ListView(
          // Eager build: the form is short enough (4 cards) and fields
          // must be reachable for links/IME without scroll-first.
          // (cacheExtent: the new scrollCacheExtent is not exported.)
          // ignore: deprecated_member_use
          cacheExtent: 4000,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader('Execution',
                      subtitle: 'Required fields are marked *',
                      padding: const EdgeInsets.only(bottom: 16)),
                  GumiTextField(
                    label: 'Instrument',
                    controller: _instrument,
                    hint: 'XAUUSD',
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Text('Direction', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _DirectionToggle(
                    value: _direction,
                    onChanged: (v) {
                      setState(() => _direction = v);
                      _recalcAuto();
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Account Type', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _AccountTypeToggle(
                    value: _accountType,
                    onChanged: (v) => setState(() => _accountType = v),
                  ),
                  const SizedBox(height: 16),
                  NumericField(
                    label: 'Entry Price',
                    controller: _entry,
                    validator: _numValidator,
                  ),
                  const SizedBox(height: 16),
                  NumericField(
                    label: 'Exit Price',
                    controller: _exit,
                    validator: _numValidator,
                  ),
                  const SizedBox(height: 16),
                  NumericField(
                    label: 'Stop Loss',
                    controller: _stopLoss,
                    validator: (v) =>
                        (v ?? '').isEmpty ? null : _numValidator(v),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _stopLoss,
                    builder: (context, value, _) => Text(
                      'Without a stop loss you cannot review risk per trade later.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: value.text.isEmpty
                            ? c.semanticWarning
                            : c.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NumericField(
                    label: 'Take Profit',
                    controller: _takeProfit,
                    validator: (v) =>
                        (v ?? '').isEmpty ? null : _numValidator(v),
                  ),
                  const SizedBox(height: 16),
                  NumericField(
                    label: 'Lot Size',
                    controller: _lotSize,
                    suffixText: 'lots',
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Required';
                      final n = double.tryParse(v!);
                      if (n == null || n <= 0) return 'Must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  NumericField(
                    label: 'Profit/Loss',
                    controller: _profitLoss,
                    suffixText: currency,
                    allowNegative: true,
                    onChanged: (_) {
                      if (!_writingAuto) _plTouched = true;
                    },
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Required';
                      if (double.tryParse(v!) == null) return 'Enter a number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  NumericField(
                    label: 'Risk/Reward',
                    controller: _riskReward,
                    onChanged: (_) {
                      if (!_writingAuto) _rrTouched = true;
                    },
                    validator: (v) =>
                        (v ?? '').isEmpty ? null : _numValidator(v),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Auto-calculated from prices using default MT5 contract '
                    'sizes (P0-08) — edit freely if your broker differs.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: c.textMuted),
                  ),
                  const SizedBox(height: 16),
                  DateTimeField(
                    label: 'Open Time',
                    value: _openTime,
                    requiredMark: true,
                    onChanged: (v) => setState(() => _openTime = v),
                  ),
                  const SizedBox(height: 16),
                  DateTimeField(
                    label: 'Close Time',
                    value: _closeTime,
                    requiredMark: true,
                    onChanged: (v) => setState(() => _closeTime = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader('Trading Context',
                      padding: const EdgeInsets.only(bottom: 16)),
                  GumiTextField(
                    label: 'Strategy',
                    controller: _strategy,
                    hint: 'London Breakout',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  SelectField<String>(
                    label: 'Session',
                    value: _session,
                    items: const ['Sydney', 'Tokyo', 'London', 'New York'],
                    onChanged: (v) => setState(() => _session = v),
                    hint: 'Optional',
                  ),
                  const SizedBox(height: 16),
                  GumiTextField(
                    label: 'Confluence (comma separated)',
                    controller: _confluence,
                    hint: 'HTF bias, liquidity sweep',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // M-7 (DESIGN.md §5.7): Mistake belongs to Psychology.
                  SectionHeader('Psychology',
                      padding: const EdgeInsets.only(bottom: 16)),
                  GumiTextField(label: 'Emotion', controller: _emotion),
                  const SizedBox(height: 16),
                  GumiTextField(
                    label: 'Mistake Tags (comma separated)',
                    controller: _mistakeTags,
                    hint: 'revenge trading, overtrade',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader('Reflection',
                      padding: const EdgeInsets.only(bottom: 16)),
                  GumiTextField(
                    label: 'Lesson Learned',
                    controller: _lesson,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  GumiTextField(
                    label: 'Notes',
                    controller: _notes,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: widget.editing != null ? 'Save Changes' : 'Save Trade',
              loading: _saving,
              onPressed: _save,
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }

  static String? _numValidator(String? v) {
    if ((v ?? '').isEmpty) return 'Required';
    if (double.tryParse(v!) == null) return 'Enter a number';
    return null;
  }
}

/// BUY / SELL segmented toggle — two choices never need a dropdown.
class _DirectionToggle extends StatelessWidget {
  const _DirectionToggle({required this.value, required this.onChanged});

  final TradeDirection? value;
  final ValueChanged<TradeDirection?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;

    return SegmentedButton<TradeDirection>(
      segments: [
        ButtonSegment(
          value: TradeDirection.buy,
          label: Text('BUY', style: theme.textTheme.labelMedium),
        ),
        ButtonSegment(
          value: TradeDirection.sell,
          label: Text('SELL', style: theme.textTheme.labelMedium),
        ),
      ],
      selected: value == null ? const <TradeDirection>{} : {value!},
      onSelectionChanged: (s) => onChanged(s.isEmpty ? null : s.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accentSilver.withValues(alpha: 0.87)
              : c.bgSecondary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.bgPrimary
              : c.textSecondary,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: c.borderSubtle)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// REAL / FUNDED segmented toggle (DATABASE.md §4.1 accountType).
class _AccountTypeToggle extends StatelessWidget {
  const _AccountTypeToggle({required this.value, required this.onChanged});

  final TradeAccountType value;
  final ValueChanged<TradeAccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;

    return SegmentedButton<TradeAccountType>(
      segments: [
        ButtonSegment(
          value: TradeAccountType.real,
          label: Text('REAL', style: theme.textTheme.labelMedium),
        ),
        ButtonSegment(
          value: TradeAccountType.funded,
          label: Text('FUNDED', style: theme.textTheme.labelMedium),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accentSilver.withValues(alpha: 0.87)
              : c.bgSecondary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.bgPrimary
              : c.textSecondary,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: c.borderSubtle)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
