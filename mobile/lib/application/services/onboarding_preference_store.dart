import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingPreferenceStore {
  Future<bool> hasCompletedInitialSetup();

  Future<void> markInitialSetupCompleted();
}

class SharedPreferencesOnboardingPreferenceStore
    implements OnboardingPreferenceStore {
  const SharedPreferencesOnboardingPreferenceStore();

  static const _completedKey = 'onboarding.initial_setup_completed';

  @override
  Future<bool> hasCompletedInitialSetup() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_completedKey) ?? false;
  }

  @override
  Future<void> markInitialSetupCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey, true);
  }
}
