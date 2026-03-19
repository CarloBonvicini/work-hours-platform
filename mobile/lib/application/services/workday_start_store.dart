import 'package:shared_preferences/shared_preferences.dart';

abstract class WorkdayStartStore {
  Future<int?> loadStartMinutes(String isoDate);

  Future<void> saveStartMinutes(String isoDate, int startMinutes);

  Future<void> clearStartMinutes(String isoDate);
}

class SharedPreferencesWorkdayStartStore implements WorkdayStartStore {
  const SharedPreferencesWorkdayStartStore();

  static const _keyPrefix = 'workday.start.';

  @override
  Future<int?> loadStartMinutes(String isoDate) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt('$_keyPrefix$isoDate');
  }

  @override
  Future<void> saveStartMinutes(String isoDate, int startMinutes) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      '$_keyPrefix$isoDate',
      startMinutes.clamp(0, (23 * 60) + 59),
    );
  }

  @override
  Future<void> clearStartMinutes(String isoDate) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_keyPrefix$isoDate');
  }
}
