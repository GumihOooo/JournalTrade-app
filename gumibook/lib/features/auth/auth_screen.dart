import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart';

import '../../core/appwrite/appwrite_failure_mapper.dart';
import '../../core/design/gumi.dart';
import '../../core/providers/auth_provider.dart';
import '../settings/user_settings_repository.dart';

/// Auth UI (P0-06.03..06.09, DESIGN.md §5.3).
///
/// Login/register in one compact liquid-glass card. Success flips the
/// auth state; GoRouter redirect pushes the dashboard — no manual
/// routing.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registerMode = false;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final auth = ref.read(authControllerProvider.notifier);
    final action = _registerMode
        ? auth.register(_email.text.trim(), _password.text)
        : auth.login(_email.text.trim(), _password.text);

    try {
      await action;
      // Success: auth state flips; router redirect owns navigation.
      // Default settings document (P0-06.12) — fire-and-forget; a second
      // signup attempt reconciles via 409.
      if (_registerMode) {
        unawaited(
          ref
              .read(userSettingsRepositoryProvider)
              .ensureDefault()
              // Fire-and-forget: settings are reconciled on next
              // login (409 = exists); never crash the signup flow.
              .catchError((_) {}),
        );
      }
    } on AppwriteException catch (e) {
      if (mounted) _showSnack(AppwriteFailureMapper.map(e).message);
    } catch (_) {
      if (mounted) _showSnack('Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            // Abstract candlestick silhouette, low-opacity silver.
            const Align(
              alignment: Alignment.bottomCenter,
              child: _CandlestickBackdrop(),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: LGCard(
                    useOwnLayer: true,
                    quality: LGQuality.standard,
                    padding: const EdgeInsets.all(24),
                    shape: LiquidRoundedSuperellipse(borderRadius: 24),
                    settings: const LiquidGlassSettings(
                      glassColor: Color.fromARGB(26, 255, 255, 255),
                      blur: 12,
                      thickness: 12,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _registerMode ? 'Create Account' : 'Welcome Back',
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          GumiTextField(
                            label: 'Email',
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),
                          GumiPasswordField(
                            label: 'Password',
                            controller: _password,
                            autofillHints: const [AutofillHints.password],
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: _registerMode ? 'Sign Up' : 'Log In',
                            loading: _submitting,
                            onPressed: _submit,
                            expanded: true,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () =>
                                    setState(() => _registerMode = !_registerMode),
                            child: Text(
                              _registerMode
                                  ? 'Already have an account? Log In'
                                  : 'No account? Sign Up',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    final ok = RegExp(r'^[\w\.\-+]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(email);
    return ok ? null : 'Enter a valid email address.';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }
}

/// Decorative thin candlestick bars along the bottom edge.
/// Monochrome silver, ~8% opacity — never competes with the form.
class _CandlestickBackdrop extends StatelessWidget {
  const _CandlestickBackdrop();

  /// (x ratio, body height, wick length).
  static const _bars = <(double, double, double)>[
    (0.00, 40, 10),
    (0.08, 70, 22),
    (0.16, 55, 8),
    (0.24, 95, 30),
    (0.32, 62, 12),
    (0.40, 120, 40),
    (0.48, 80, 18),
    (0.56, 140, 50),
    (0.64, 90, 26),
    (0.72, 65, 14),
    (0.80, 105, 34),
    (0.88, 75, 20),
    (0.96, 45, 12),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    final silver = c.accentSilver.withValues(alpha: 0.08);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 180,
          width: double.infinity,
          child: CustomPaint(
            painter: _CandlestickPainter(
              bars: _bars,
              color: silver,
              areaWidth: width,
            ),
          ),
        );
      },
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  const _CandlestickPainter({
    required this.bars,
    required this.color,
    required this.areaWidth,
  });

  final List<(double, double, double)> bars;
  final Color color;
  final double areaWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()..color = color;
    final wickPaint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (final (xRatio, bodyHeight, wickLength) in bars) {
      final x = xRatio * areaWidth;
      final wickTop = size.height - bodyHeight - wickLength;
      final bodyTop = size.height - bodyHeight;

      // Thin wick line above the body.
      canvas.drawLine(
        Offset(x, wickTop),
        Offset(x, bodyTop),
        wickPaint,
      );

      // Candle body: 10-wide, 45% height rounded bar.
      final bodyRect = Rect.fromLTWH(x - 5, bodyTop, 10, bodyHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(3)),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter old) =>
      old.color != color || old.areaWidth != areaWidth;
}
