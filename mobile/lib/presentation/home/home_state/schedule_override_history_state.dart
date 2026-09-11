// Storico undo/redo della bozza di orario del giorno.

part of '../home_screen.dart';

mixin _ScheduleOverrideHistoryState on _HomeScreenStateBase {
  String _scheduleOverrideHistoryDateKeyFor(DateTime date) {
    return DashboardService.defaultEntryDateOf(date);
  }

  bool _sameScheduleOverrideDraftState(
    ScheduleOverrideDraftState left,
    ScheduleOverrideDraftState right,
  ) {
    return _sameDaySchedule(left.schedule, right.schedule) &&
        _samePauseWindow(left.pauseWindow, right.pauseWindow);
  }

  ScheduleOverrideDraftState _currentScheduleOverrideDraftState({
    DaySchedule? fallbackSchedule,
  }) {
    final effectiveFallback =
        fallbackSchedule ?? _fallbackScheduleForSelectedDate();
    return ScheduleOverrideDraftState(
      schedule: _resolveCurrentScheduleDraft(effectiveFallback),
      pauseWindow: _selectedDayPauseWindowDraft(),
    );
  }

  @override
  void _resetScheduleOverrideHistoryForDate(
    DateTime date, {
    required DaySchedule schedule,
    CalendarPauseWindow? pauseWindow,
  }) {
    _scheduleOverrideHistoryDateKey = _scheduleOverrideHistoryDateKeyFor(date);
    _scheduleOverrideHistory = [
      ScheduleOverrideDraftState(schedule: schedule, pauseWindow: pauseWindow),
    ];
    _scheduleOverrideHistoryIndex = 0;
  }

  @override
  void _primeScheduleOverrideHistoryFromCurrentDisplay() {
    final displayedState = _displayedScheduleStateForSelectedDate();
    final historyEntry = ScheduleOverrideDraftState(
      schedule: displayedState.schedule,
      pauseWindow: displayedState.pauseWindow,
    );
    final dateKey = _scheduleOverrideHistoryDateKeyFor(_selectedDate);
    if (_scheduleOverrideHistoryDateKey != dateKey ||
        _scheduleOverrideHistory.isEmpty ||
        _scheduleOverrideHistoryIndex < 0) {
      _resetScheduleOverrideHistoryForDate(
        _selectedDate,
        schedule: historyEntry.schedule,
        pauseWindow: historyEntry.pauseWindow,
      );
      return;
    }

    if (_scheduleOverrideHistory.length == 1 &&
        _scheduleOverrideHistoryIndex == 0 &&
        !_sameScheduleOverrideDraftState(
          _scheduleOverrideHistory.first,
          historyEntry,
        )) {
      _resetScheduleOverrideHistoryForDate(
        _selectedDate,
        schedule: historyEntry.schedule,
        pauseWindow: historyEntry.pauseWindow,
      );
    }
  }

  @override
  void _pushCurrentScheduleOverrideDraftToHistory() {
    final dateKey = _scheduleOverrideHistoryDateKeyFor(_selectedDate);
    final nextEntry = _currentScheduleOverrideDraftState();
    if (_scheduleOverrideHistoryDateKey != dateKey ||
        _scheduleOverrideHistory.isEmpty ||
        _scheduleOverrideHistoryIndex < 0) {
      _resetScheduleOverrideHistoryForDate(
        _selectedDate,
        schedule: nextEntry.schedule,
        pauseWindow: nextEntry.pauseWindow,
      );
      return;
    }

    final currentEntry =
        _scheduleOverrideHistory[_scheduleOverrideHistoryIndex];
    if (_sameScheduleOverrideDraftState(currentEntry, nextEntry)) {
      return;
    }

    final nextHistory =
        _scheduleOverrideHistory
            .take(_scheduleOverrideHistoryIndex + 1)
            .toList(growable: true)
          ..add(nextEntry);
    _scheduleOverrideHistory = nextHistory;
    _scheduleOverrideHistoryIndex = nextHistory.length - 1;
  }

  @override
  bool get _canUndoScheduleOverride =>
      _scheduleOverrideHistoryDateKey ==
          _scheduleOverrideHistoryDateKeyFor(_selectedDate) &&
      _scheduleOverrideHistoryIndex > 0;

  @override
  bool get _canRedoScheduleOverride =>
      _scheduleOverrideHistoryDateKey ==
          _scheduleOverrideHistoryDateKeyFor(_selectedDate) &&
      _scheduleOverrideHistoryIndex >= 0 &&
      _scheduleOverrideHistoryIndex < (_scheduleOverrideHistory.length - 1);

  Future<void> _restoreScheduleOverrideHistoryEntry(int index) async {
    if (index < 0 || index >= _scheduleOverrideHistory.length) {
      return;
    }

    final historyEntry = _scheduleOverrideHistory[index];
    _applyDayScheduleDraft(
      historyEntry.schedule,
      pauseWindow: historyEntry.pauseWindow,
    );
    _clearPendingExitConfirmationForSelectedDate();
    _clearAgendaPreviewState();
    if (mounted) {
      setState(() {
        _scheduleOverrideHistoryIndex = index;
        _errorMessage = null;
      });
    } else {
      _scheduleOverrideHistoryIndex = index;
    }
    await _autosaveScheduleOverride();
  }

  @override
  Future<void> _undoScheduleOverrideDraftChange() async {
    if (!_canUndoScheduleOverride) {
      return;
    }

    await _restoreScheduleOverrideHistoryEntry(
      _scheduleOverrideHistoryIndex - 1,
    );
  }

  @override
  Future<void> _redoScheduleOverrideDraftChange() async {
    if (!_canRedoScheduleOverride) {
      return;
    }

    await _restoreScheduleOverrideHistoryEntry(
      _scheduleOverrideHistoryIndex + 1,
    );
  }
}
