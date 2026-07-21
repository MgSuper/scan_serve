import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OnboardingStorage {
  Future<bool> isCompleted();
  Future<void> setCompleted();
}

class SharedPrefsOnboardingStorage implements OnboardingStorage {
  static const _key = 'onboarding_completed';

  @override
  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> setCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
