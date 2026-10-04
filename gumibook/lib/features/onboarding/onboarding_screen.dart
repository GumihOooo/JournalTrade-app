import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../core/design/gumi.dart';
import '../../core/providers/onboarding_provider.dart';

/// Onboarding (P0-05.03..05.11, DESIGN.md §5.2).
///
/// Two pages: value proposition and the four core features. Get Started
/// persists the onboarding flag; GoRouter's redirect reacts and moves
/// the user to /auth/login. No manual routing.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                children: const [
                  _OnboardingPage1(),
                  _OnboardingPage2(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PageDots(controller: _controller),
                  const SizedBox(height: 16),
                  _GetStartedButton(controller: _controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage1 extends StatelessWidget {
  const _OnboardingPage1();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: Lottie.asset(
              'assets/animations/splash.json',
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'Track. Analyze. Improve.',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Your personal trading journal. Record every trade, '
            'understand your psychology, and grow with data.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage2 extends StatelessWidget {
  const _OnboardingPage2();

  static const _features = [
    (Icons.document_scanner_outlined, 'MT5 Screenshot Extraction',
        'Import trades from your MT5 history in seconds.'),
    (Icons.psychology_outlined, 'Psychology Journal',
        'Track emotions and mistakes behind every trade.'),
    (Icons.insights_outlined, 'Performance Analytics',
        'Win rate, RR, equity curve, and breakdowns.'),
    (Icons.lock_outline, 'Privacy-First Images',
        'Screenshots are processed on-device and never stored.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (icon, title, body) in _features) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28, color: c.accentSilver),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.controller});

  final PageController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = controller.hasClients && controller.page != null
            ? controller.page!
            : 0.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 2; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: page.round() == i ? c.accentSilver : c.borderFocus,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GetStartedButton extends ConsumerWidget {
  const _GetStartedButton({required this.controller});

  final PageController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PrimaryButton(
      label: 'Get Started',
      expanded: true,
      onPressed: () async {
        final page = controller.hasClients ? controller.page?.round() ?? 0 : 0;
        if (page < 1) {
          controller.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          return;
        }
        // Persist the flag; GoRouter redirect reacts and routes to
        // /auth/login. No manual navigation here.
        await ref.read(onboardingProvider.notifier).setDone();
      },
    );
  }
}
