import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Local onboarding flag (P0-04.04, IMPLEMENTATION.md §9).
/// Non-sensitive, safe in shared_preferences.
///
/// Observable: state is the flag itself, so the router refresh fires
/// when setDone() flips it.
class OnboardingController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConfig.onboardingDoneKey) ?? false;
  }

  Future<void> setDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.onboardingDoneKey, true);
    state = const AsyncData(true);
  }
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingController, bool>(OnboardingController.new);
