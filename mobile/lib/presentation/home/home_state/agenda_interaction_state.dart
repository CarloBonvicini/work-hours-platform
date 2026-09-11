// Interazione con l'agenda: anteprima e applicazione delle modifiche trascinate.

part of '../home_screen.dart';

mixin _AgendaInteractionState on _HomeScreenStateBase {
  void _setAgendaPreviewState({
    int? startMinutes,
    int? endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  }) {
    _agendaPreviewStartMinutes = startMinutes;
    _agendaPreviewEndMinutes = endMinutes;
    _agendaPreviewBreakMinutes = breakMinutes;
    _agendaPreviewPauseStartMinutes = pauseStartMinutes;
    _agendaPreviewPauseEndMinutes = pauseEndMinutes;
  }

  @override
  void _clearAgendaPreviewState() {
    _setAgendaPreviewState();
  }

  @override
  CalendarPauseWindow? _agendaPreviewPauseWindow() {
    final pauseStartMinutes = _agendaPreviewPauseStartMinutes;
    final pauseEndMinutes = _agendaPreviewPauseEndMinutes;
    if (pauseStartMinutes == null ||
        pauseEndMinutes == null ||
        pauseEndMinutes <= pauseStartMinutes) {
      return null;
    }

    return CalendarPauseWindow(
      pauseStartMinutes: pauseStartMinutes,
      resumeMinutes: pauseEndMinutes,
    );
  }

  @override
  DaySchedule _resolveAgendaPreviewSchedule(DaySchedule fallbackSchedule) {
    final previewStartMinutes = _agendaPreviewStartMinutes;
    final previewEndMinutes = _agendaPreviewEndMinutes;
    if (previewStartMinutes == null ||
        previewEndMinutes == null ||
        previewEndMinutes <= previewStartMinutes) {
      return fallbackSchedule;
    }

    final previewBreakMinutes =
        _agendaPreviewBreakMinutes ??
        math.max(0, fallbackSchedule.breakMinutes);
    return DaySchedule(
      targetMinutes: math.max(
        0,
        (previewEndMinutes - previewStartMinutes) - previewBreakMinutes,
      ),
      startTime: formatTimeInput(previewStartMinutes),
      endTime: formatTimeInput(previewEndMinutes),
      breakMinutes: previewBreakMinutes,
    );
  }

  @override
  void _updateScheduleOverrideFromAgenda({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  }) {
    final normalizedStart = startMinutes.clamp(0, 24 * 60).toInt();
    final normalizedEnd = endMinutes.clamp(0, 24 * 60).toInt();
    if (normalizedEnd <= normalizedStart) {
      return;
    }

    _seedScheduleOverrideDraftFromCurrentDisplay();
    _scheduleOverrideStartTimeController.text = formatTimeInput(
      normalizedStart,
    );
    _scheduleOverrideEndTimeController.text = formatTimeInput(normalizedEnd);
    if (breakMinutes != null) {
      _scheduleOverrideBreakController.text = formatBreakInput(
        breakMinutes.clamp(0, normalizedEnd - normalizedStart),
      );
    }
    _setSelectedDayPauseWindowDraft(
      pauseStartMinutes != null &&
              pauseEndMinutes != null &&
              pauseEndMinutes > pauseStartMinutes
          ? CalendarPauseWindow(
              pauseStartMinutes: pauseStartMinutes,
              resumeMinutes: pauseEndMinutes,
            )
          : null,
    );
    assert(() {
      debugPrint(
        '[agenda-commit] date=${DashboardService.defaultEntryDateOf(_selectedDate)} '
        'start=${formatTimeInput(normalizedStart)} end=${formatTimeInput(normalizedEnd)} '
        'break=${breakMinutes ?? '-'} '
        'pauseStart=${pauseStartMinutes == null ? '-' : formatTimeInput(pauseStartMinutes)} '
        'pauseEnd=${pauseEndMinutes == null ? '-' : formatTimeInput(pauseEndMinutes)}',
      );
      return true;
    }());
    _clearAgendaPreviewState();
    _clearPendingExitConfirmationForSelectedDate();
    setState(() {
      _errorMessage = null;
    });
    _pushCurrentScheduleOverrideDraftToHistory();
    unawaited(_autosaveScheduleOverride());
  }

  @override
  void _previewScheduleOverrideFromAgenda({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  }) {
    final normalizedStart = startMinutes.clamp(0, 24 * 60).toInt();
    final normalizedEnd = endMinutes.clamp(0, 24 * 60).toInt();
    if (normalizedEnd <= normalizedStart) {
      return;
    }

    final normalizedBreakMinutes = breakMinutes?.clamp(
      0,
      normalizedEnd - normalizedStart,
    );
    setState(() {
      _setAgendaPreviewState(
        startMinutes: normalizedStart,
        endMinutes: normalizedEnd,
        breakMinutes: normalizedBreakMinutes,
        pauseStartMinutes: pauseStartMinutes,
        pauseEndMinutes: pauseEndMinutes,
      );
      _errorMessage = null;
    });
  }

  @override
  void _clearScheduleOverrideAgendaPreview() {
    if (_agendaPreviewStartMinutes == null &&
        _agendaPreviewEndMinutes == null &&
        _agendaPreviewBreakMinutes == null &&
        _agendaPreviewPauseStartMinutes == null &&
        _agendaPreviewPauseEndMinutes == null) {
      return;
    }

    setState(_clearAgendaPreviewState);
  }

  @override
  void _setAgendaInteracting(bool isInteracting) {
    if (!mounted || _isAgendaInteracting == isInteracting) {
      return;
    }
    setState(() {
      _isAgendaInteracting = isInteracting;
    });
  }
}
