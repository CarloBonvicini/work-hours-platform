// Ore registrate del giorno, quando l'orario c'e' ma le ore no.

part of '../home_screen.dart';

mixin _DayHoursRegistrationState on _HomeScreenStateBase {
  /// Registra le ore che l'orario del giorno racconta ma che non risultano.
  ///
  /// Serve ai giorni gia' timbrati che non hanno mai prodotto una
  /// registrazione: l'orario resta com'e', a cambiare sono solo le ore.
  @override
  Future<void> _registerUnrecordedHours(int minutes) async {
    if (minutes <= 0) {
      return;
    }

    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);
    try {
      final nextSnapshot = await widget.dashboardService.upsertDayWorkedHours(
        date: isoDate,
        minutes: minutes,
        noteIfNew: 'Ore recuperate',
      );
      if (!mounted) {
        return;
      }

      await _cacheSnapshot(nextSnapshot);
      if (!mounted) {
        return;
      }

      _hydrateControllers(nextSnapshot, _selectedDate);
      setState(() {
        _snapshot = nextSnapshot;
        _errorMessage = null;
      });
      await _queueCloudBackup();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(error);
      });
    }
  }
}
