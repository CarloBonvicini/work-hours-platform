import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const update = AppUpdate(
    currentVersion: '0.1.8',
    latestVersion: '0.1.9',
    downloadUrl: 'https://example.invalid/app-release.apk',
    releasePageUrl: 'https://example.invalid/releases/mobile-v0.1.9',
  );

  test('prompts immediately when version was never snoozed', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesUpdateReminderStore();

    final shouldPrompt = await store.shouldPromptFor(update);

    expect(shouldPrompt, isTrue);
  });

  test('does not prompt while snooze is active for same version', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesUpdateReminderStore(
      remindLaterDuration: Duration(hours: 1),
    );

    await store.remindLater(update);
    final shouldPrompt = await store.shouldPromptFor(update);

    expect(shouldPrompt, isFalse);
  });
}
