import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/appwrite/appwrite_failure_mapper.dart';
import '../../core/design/gumi.dart';
import '../../core/errors/failure.dart';
import '../../core/providers/auth_provider.dart';
import '../journal/journal_provider.dart';
import '../trades/export/trade_export_controller.dart';
import '../watchlist/watchlist_provider.dart';
import 'delete_service.dart';
import 'user_settings_provider.dart';
import 'user_settings_repository.dart';

/// Settings (P0-12, DESIGN.md §5.15, PRD §14): Profile, Appearance,
/// Trading Tools, and Account sections in separate GlassCards.
/// Destructive actions confirm first; failures surface as snackbars,
/// never crashes.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _balanceCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _tradingSinceCtrl = TextEditingController();
  // M-4: live for the whole screen so the password dialog owns no
  // lifecycle of its own; cleared after every dialog run.
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  String _currency = 'USD';

  static const _currencies = ['USD', 'EUR', 'IDR', 'SGD', 'JPY', 'GBP'];

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _tradingSinceCtrl.dispose();
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  void _fillFrom(UserSettings s) {
    // P0-12: seed controllers with the loaded values; user edits after
    // this point win and are never clobbered by re-listens.
    _seeded = true;
    _balanceCtrl.text = s.startingBalance == null ? '' : _fmtNum(s.startingBalance!);
    _displayNameCtrl.text = s.displayName ?? '';
    _bioCtrl.text = s.bio ?? '';
    _tradingSinceCtrl.text = s.tradingSince == null
        ? ''
        : _fmtDate(s.tradingSince!);
    _currency = s.balanceCurrency ?? 'USD';
    setState(() {});
  }

  bool _seeded = false;

  static String _fmtNum(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);

  static String _fmtDate(DateTime v) {
    final local = v.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Wraps every mutation: failure surfaces as a snackbar, never a crash.
  /// Empty [success] = silent (caller already reported).
  Future<bool> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted && success.isNotEmpty) _snack(success);
      return true;
    } on Failure catch (e) {
      if (mounted) _snack(e.message);
    } on AppwriteException catch (e) {
      if (mounted) _snack(AppwriteFailureMapper.map(e).message);
    } catch (_) {
      if (mounted) _snack('Network error. Check your connection.');
    }
    return false;
  }

  // P0-12.06a + S-1/S-4/M-12: one Save for the whole Profile card.
  // Empty balance field means unset (clear); 0/negative rejected.
  Future<void> _saveProfile() async {
    final name = _displayNameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Display name must not be empty.');
      return;
    }
    DateTime? since;
    final sinceRaw = _tradingSinceCtrl.text.trim();
    if (sinceRaw.isNotEmpty) {
      since = DateTime.tryParse(sinceRaw);
      if (since == null) {
        _snack('Trading since must be a date (YYYY-MM-DD).');
        return;
      }
    }
    final balanceRaw = _balanceCtrl.text.trim();
    double? balance;
    if (balanceRaw.isNotEmpty) {
      balance = double.tryParse(balanceRaw);
      if (balance == null) {
        _snack('Starting balance must be a number.');
        return;
      }
      if (balance <= 0) {
        _snack('Starting balance must be greater than 0.');
        return;
      }
    }
    final snapshot = ref.read(userSettingsProvider).valueOrNull;
    final hadBalance = snapshot?.startingBalance != null;
    final hadSince = snapshot?.tradingSince != null;
    await _run(
      () => ref.read(settingsControllerProvider.notifier).updateProfile(
            displayName: name,
            bio: _bioCtrl.text.trim(),
            tradingSince: since,
            clearTradingSince: since == null && hadSince,
            startingBalance: balance,
            clearStartingBalance: balance == null && hadBalance,
            balanceCurrency: _currency,
            isBalanceEdit: true,
          ),
      'Profile saved.',
    );
  }

  Future<void> _pickTradingSince() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _tradingSinceCtrl.text = _fmtDate(picked));
    }
  }

  /// Explicit clear action (only visible when a balance exists): empty
  /// field + Save Profile does the same; this is the shortcut.
  Future<void> _clearBalance() async {
    _balanceCtrl.clear();
    await _run(
      () => ref.read(settingsControllerProvider.notifier).clearStartingBalance(),
      'Starting balance cleared.',
    );
  }

  Future<void> _pickCurrency() async {
    final c = context.gumiColors;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(GumiRadius.glass)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Currency',
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final cur in _currencies)
                    ListTile(
                      title: Text(cur),
                      trailing: cur == _currency
                          ? const Icon(Icons.check, size: 20)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, cur),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _currency = picked);
  }

  // P0-12.10 + M-4: password changes with inline validation inside the
  // dialog; controllers live and die with the dialog.
  Future<void> _changePassword() async {
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final p1 = _pw1;
          final p2 = _pw2;
          return AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GumiPasswordField(
                  label: 'New password',
                  controller: p1,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                GumiPasswordField(
                  label: 'Repeat new password',
                  controller: p2,
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final next = _validateNewPassword(p1.text, p2.text);
                  if (next != null) {
                    setDialogState(() => error = next);
                    return;
                  }
                  Navigator.pop(dialogContext);
                  await _run(
                    () => ref
                        .read(settingsControllerProvider.notifier)
                        .changePassword(p1.text),
                    'Password changed.',
                  );
                },
                child: const Text('Change'),
              ),
            ],
          );
        },
      ),
    );
    _pw1.clear();
    _pw2.clear();
  }

  static String? _validateNewPassword(String p1, String p2) {
    if (p1.length < 8) return 'Password must be at least 8 characters.';
    if (p1 != p2) return 'Passwords do not match.';
    return null;
  }

  // P0-12.11: destructive — confirm before killing the session.
  Future<void> _logout() async {
    final confirmed = await showGumiConfirmationDialog(
      context: context,
      title: 'Log Out',
      message: 'You will need to sign in again to access your journal.',
      confirmLabel: 'Log Out',
      destructive: false,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(authControllerProvider.notifier).logout();
      // Router redirect owns navigation to /auth/login.
    } on AppwriteException catch (e) {
      if (mounted) _snack(AppwriteFailureMapper.map(e).message);
    }
  }

  // P2-03: Delete All Data and Delete Account. Both confirm first
  // (DESIGN.md §8) and surface failures as snackbars, never crashes.
  // Confirmation uses an explicit typed word — a single "Delete" tap
  // is too easy to fire on the wrong account.
  Future<void> _deleteAllData() async {
    final confirmed = await showGumiConfirmationDialog(
      context: context,
      title: 'Delete All Data',
      message: 'This permanently deletes every trade and watchlist '
          'instrument in your account. Your account and profile stay. '
          'This cannot be undone.',
      confirmLabel: 'Delete All Data',
    );
    if (!confirmed || !mounted) return;
    final ok = await _run(
      () => ref.read(deleteServiceProvider).deleteAllData(),
      'All journal data deleted.',
    );
    if (ok) {
      // All deleted sources lose their cache: journal (Dashboard +
      // Journal) and watchlist (Market) must reflect the empty state
      // immediately, not only after a restart.
      ref.invalidate(journalProvider);
      ref.invalidate(watchlistProvider);
      ref.invalidate(userSettingsProvider);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showGumiConfirmationDialog(
      context: context,
      title: 'Delete Account',
      message: 'This permanently deletes your account and every trade, '
          'watchlist instrument, and profile setting in it. It cannot '
          'be undone.',
      confirmLabel: 'Delete Account',
    );
    if (!confirmed || !mounted) return;
    final ok = await _run(
      () => ref.read(deleteServiceProvider).deleteAccount(),
      'Account deleted.',
    );
    // On success the local session is cleared; router redirect takes
    // the user to /auth/login. On failure the snackbar reports it.
    if (!ok && mounted) return;
  }

  // P2-02.07: export + share the signed-in user's full trade list.
  // Busy guard prevents double taps from stacking share sheets.
  bool _exporting = false;

  Future<void> _exportData(String format) async {
    if (_exporting) return;
    _exporting = true;
    try {
      final count = await ref
          .read(tradeExportControllerProvider)
          .exportAndShare(format);
      if (mounted) {
        _snack(count == 0
            ? 'No trades to export yet.'
            : 'Shared $count ${count == 1 ? 'trade' : 'trades'} '
                'as ${format.toUpperCase()}.');
      }
    } on Failure catch (e) {
      if (mounted) _snack(e.message);
    } on AppwriteException catch (e) {
      if (mounted) _snack(AppwriteFailureMapper.map(e).message);
    } catch (_) {
      if (mounted) _snack('Export failed. Check your connection.');
    } finally {
      _exporting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final settings = ref.watch(userSettingsProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    // Seed controllers when settings load — user edits win after. Listens
    // fire on every change (including post-save invalidation), so guard
    // with a flag: only the FIRST load seeds, edits are never clobbered.
    // Seed controllers once when settings first load (P0-12.04..06);
    // user edits afterwards are never clobbered by re-listens.
    ref.listen(userSettingsProvider, (prev, next) {
      final n = next.valueOrNull;
      if (!_seeded && n != null) _fillFrom(n);
    });

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: ListView(
        // Build everything eagerly: 4 cards is nothing and keeps
        // off-screen sections findable for tests and semantics.
        scrollCacheExtent: const ScrollCacheExtent.pixels(3000),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // --- Profile & Trading Preferences ---
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Profile',
                    padding: const EdgeInsets.only(bottom: 16)),
                GumiTextField(
                  label: 'Display Name',
                  controller: _displayNameCtrl,
                  hint: 'Your trader name',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                ),
                const SizedBox(height: 14),
                // P0-12.03: email is read-only — auth source of truth.
                _ReadOnlyField(
                  label: 'Email',
                  value: user?.email ?? '—',
                ),
                const SizedBox(height: 14),
                // P0-12.05: bio is a short multiline blurb.
                GumiTextField(
                  label: 'Bio',
                  controller: _bioCtrl,
                  maxLines: 2,
                  hint: 'Short intro (optional)',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                ),
                const SizedBox(height: 14),
                // M-2: tap to pick; clear button unsets the date.
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickTradingSince,
                        child: _ReadOnlyField(
                          label: 'Trading Since',
                          value: _tradingSinceCtrl.text.isEmpty
                              ? 'Tap to pick date'
                              : _tradingSinceCtrl.text,
                          muted: _tradingSinceCtrl.text.isEmpty,
                        ),
                      ),
                    ),
                    if (_tradingSinceCtrl.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear trading since',
                        onPressed: () =>
                            setState(() => _tradingSinceCtrl.clear()),
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: c.borderSubtle, height: 1),
                const SizedBox(height: 16),
                SectionHeader('Capital & Currency',
                    padding: const EdgeInsets.only(bottom: 12)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: GumiTextField(
                        label: 'Starting Balance',
                        controller: _balanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        hint: 'e.g. 1000',
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _pickCurrency,
                        borderRadius: BorderRadius.circular(GumiRadius.control),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: c.surfaceElevated,
                            borderRadius: BorderRadius.circular(GumiRadius.control),
                            border: Border.all(color: c.borderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_currency, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              const Icon(Icons.keyboard_arrow_down, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (settings.valueOrNull?.balanceSetAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Last set ${_fmtDate(settings.value!.balanceSetAt!)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: c.textMuted),
                    ),
                  ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Save Profile',
                  onPressed: _saveProfile,
                  expanded: true,
                ),
                if (settings.valueOrNull?.startingBalance != null) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: _clearBalance,
                      child: const Text('Clear Starting Balance'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // --- Appearance (P0-12.07/08) ---
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Appearance',
                    padding: const EdgeInsets.only(bottom: 16)),
                Row(
                  children: [
                    const Icon(Icons.dark_mode_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Dark Theme',
                          style: theme.textTheme.bodyMedium),
                    ),
                    // P0-12.08: dark is locked for MVP — active, not
                    // switchable.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.surfaceGlass,
                        borderRadius: BorderRadius.all(
                            Radius.circular(GumiRadius.control)),
                        border: Border.all(color: c.borderSubtle),
                      ),
                      child: Text(
                        'LOCKED',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // --- Privacy (P1-06.08) ---
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Privacy',
                    padding: const EdgeInsets.only(bottom: 8)),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.document_scanner_outlined),
                    title: const Text(
                        'MT5 screenshots are read by AI to extract your '
                        'trade data. The image is sent transiently to the '
                        'AI service for reading only — it is never stored '
                        'on your device, on GumiBook servers, or by the AI '
                        'provider after processing.'),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: const Text(
                        'Your journal data lives in your private account. '
                        'Only you can access it.'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // --- Data Export (P2-02) ---
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Data Export',
                    padding: const EdgeInsets.only(bottom: 8)),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.data_object),
                    title: const Text('Export as JSON'),
                    subtitle: Text('All trades, ISO 8601 dates',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.textMuted)),
                    trailing: const Icon(Icons.share_outlined),
                    onTap: () => _exportData('json'),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.table_chart_outlined),
                    title: const Text('Export as CSV'),
                    subtitle: Text('Spreadsheet-friendly, RFC 4180',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.textMuted)),
                    trailing: const Icon(Icons.share_outlined),
                    onTap: () => _exportData('csv'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // --- Trading Tools (DESIGN.md §5.15) ---
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Trading Tools',
                    padding: const EdgeInsets.only(bottom: 8)),
                // Material wrapper: ListTile ink needs a Material
                // between itself and the GlassCard's colored box.
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calculate_outlined),
                    title: const Text('Trading Calculator'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/calculator'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // --- Account (P0-12.09..11) ---
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Account',
                    padding: const EdgeInsets.only(bottom: 8)),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePassword,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout, color: c.semanticLoss),
                    title: Text('Log Out',
                        style: TextStyle(color: c.semanticLoss)),
                    onTap: _logout,
                  ),
                ),
                // P2-03: destructive data wipe — account stays.
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_sweep_outlined,
                        color: c.semanticLoss),
                    title: Text('Delete All Data',
                        style: TextStyle(color: c.semanticLoss)),
                    subtitle: Text('Trades and watchlist',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.textMuted)),
                    onTap: _deleteAllData,
                  ),
                ),
                // P2-03.05..07: real deletion flow.
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_off_outlined),
                    title: const Text('Delete Account'),
                    onTap: _deleteAccount,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-editable display row (email, picked dates).
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        enabled: false,
      ),
      child: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: muted ? theme.hintColor : null,
        ),
      ),
    );
  }
}
