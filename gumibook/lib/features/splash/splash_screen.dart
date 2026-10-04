import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../core/design/gumi.dart';
import '../../core/providers/auth_provider.dart';

/// Minimalist in-app splash (DESIGN.md §5.1). Native splash is a solid
/// dark color; this widget plays the Lottie centered, waits until the
/// auth session check resolves, then hands off to the router redirect.
///
/// ponytail: Lottie plays at half speed via controller duration
/// (composition.duration * 2); the animation and the session check
/// run in parallel, so the slower one gates the hand-off.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timeoutTimer;
  bool _animationDone = false;
  bool _navigated = false;

  /// Asset data: last visual keyframe is frame 180 of op 210 (60fps), so
  /// the animation is visually static in its final 0.5s. Full speed
  /// (1.0) ends at 3.5s with a natural tail; half speed stretched the
  /// static tail to a full second, which reads as "splash skipped early".
  static const double _speed = 1.0;

  /// Hard ceiling: never trap the user on a slow device.
  static const _maxHold = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _timeoutTimer = Timer(_maxHold, _timeoutFallback);
  }

  void _onLoaded(LottieComposition composition) {
    // onLoaded can fire again if the composition reloads; guard against
    // stacked status listeners.
    if (_animationDone) return;
    _controller
      ..duration = composition.duration * (1 / _speed)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationDone = true;
          _maybeLeave();
        }
      })
      ..forward();
  }

  /// Timeout fallback: slow asset decode or a hung load must not trap
  /// the user. Fires only if the animation never completed.
  void _timeoutFallback() {
    if (_animationDone || _navigated) return;
    debugPrint('splash: timeout fallback fired');
    _animationDone = true;
    // S-6: offline boot keeps auth unknown; show retry instead of a
    // dead splash (the router would bounce /app/* back here anyway).
    if (ref.read(authStateProvider) == AuthStatus.unknown) {
      if (mounted) setState(() => _offline = true);
      return;
    }
    _maybeLeave();
  }

  bool _offline = false;

  /// Re-run the boot probe (S-6 retry).
  Future<void> _retry() async {
    setState(() => _offline = false);
    ref.invalidate(authCheckProvider);
  }

  /// Fallback when the animation asset fails: mark done, keep waiting
  /// for auth. Never trap the user on splash.
  void _onLoadFailed() {
    if (_animationDone) return;
    _animationDone = true;
    _maybeLeave();
  }

  /// Leave once the animation finished AND the session check resolved.
  void _maybeLeave() {
    final auth = ref.read(authStateProvider);
    if (!_animationDone || _navigated) return;
    if (auth == AuthStatus.unknown) return; // still checking/offline
    _navigated = true;
    context.go('/app/dashboard');
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = GumiColors.dark;

    // Auth status change can resolve after the animation; re-check.
    ref.listen(authStateProvider, (_, _) => _maybeLeave());

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: SizedBox.expand(
        child: Center(
          child: _offline
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not reach the server.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check your connection and try again.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Retry',
                      onPressed: _retry,
                    ),
                  ],
                )
              : SizedBox(
                  width: 180,
                  height: 180,
                  child: Lottie.asset(
                    'assets/animations/splash.json',
                    controller: _controller,
                    animate: true,
                    repeat: false,
                    alignment: Alignment.center,
                    fit: BoxFit.contain,
                    width: 180,
                    height: 180,
                    onLoaded: _onLoaded,
                    // Broken/missing asset must not trap the user on splash.
                    errorBuilder: (context, error, stackTrace) {
                      _onLoadFailed();
                      return const SizedBox.shrink();
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
