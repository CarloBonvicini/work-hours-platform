import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';

abstract class UpdateReminderStore {
  Future<bool> shouldPromptFor(AppUpdate update);

  Future<void> remindLater(AppUpdate update);

  Future<void> deferAfterOpening(AppUpdate update);
}

class SharedPreferencesUpdateReminderStore implements UpdateReminderStore {
  const SharedPreferencesUpdateReminderStore({
    this.remindLaterDuration = const Duration(hours: 6),
    this.deferAfterOpeningDuration = const Duration(minutes: 30),
  });

  final Duration remindLaterDuration;
  final Duration deferAfterOpeningDuration;

  static const _versionKey = 'update_reminder.version';
  static const _untilEpochMsKey = 'update_reminder.until_epoch_ms';

  @override
  Future<bool> shouldPromptFor(AppUpdate update) async {
    final preferences = await SharedPreferences.getInstance();
    final reminderVersion = preferences.getString(_versionKey);
    final reminderUntilEpochMs = preferences.getInt(_untilEpochMsKey);

    if (reminderVersion != update.latestVersion || reminderUntilEpochMs == null) {
      return true;
    }

    final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
    if (nowEpochMs >= reminderUntilEpochMs) {
      await preferences.remove(_versionKey);
      await preferences.remove(_untilEpochMsKey);
      return true;
    }

    return false;
  }

  @override
  Future<void> remindLater(AppUpdate update) {
    return _saveReminder(
      version: update.latestVersion,
      duration: remindLaterDuration,
    );
  }

  @override
  Future<void> deferAfterOpening(AppUpdate update) {
    return _saveReminder(
      version: update.latestVersion,
      duration: deferAfterOpeningDuration,
    );
  }

  Future<void> _saveReminder({
    required String version,
    required Duration duration,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final remindUntil = DateTime.now().add(duration).millisecondsSinceEpoch;
    await preferences.setString(_versionKey, version);
    await preferences.setInt(_untilEpochMsKey, remindUntil);
  }
}
