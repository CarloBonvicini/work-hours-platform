// Bozza e salvataggio dell'orario del giorno selezionato (override), pause e preset.

part of '../home_screen.dart';

mixin _ScheduleOverridesState on _HomeScreenStateBase {
  @override
  Future<void> _removeScheduleOverride() async {
    setState(() {
      _isSavingScheduleOverride = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await widget.dashboardService.removeScheduleOverride(
        date: DashboardService.defaultEntryDateOf(_selectedDate),
      );

      if (!mounted) {
        return;
      }

      await _cacheSnapshot(snapshot);
      if (!mounted) {
        return;
      }
      _hydrateControllers(snapshot, _selectedDate);
      setState(() {
        _snapshot = snapshot;
        _isSavingScheduleOverride = false;
      });
      await _queueCloudBackup();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(error);
        _isSavingScheduleOverride = false;
      });
    }
  }

  /// Uscita da salvare: vuota finche' e' solo la previsione.
  ///
  /// L'uscita calcolata da entrata + ore + pausa non e' un fatto registrato,
  /// quindi non va scritta nel giorno. Prima per non salvarla si saltava tutto
  /// il salvataggio, e cambiando giorno si perdevano anche entrata, ore e pausa.
  String get _persistableScheduleOverrideEndTimeText =>
      _hasPendingExitConfirmationForSelectedDate
      ? ''
      : _scheduleOverrideEndTimeController.text;

  @override
  Future<void> _autosaveScheduleOverride() async {
    _scheduleOverrideAutosaveQueued = true;
    if (_isSavingScheduleOverride) {
      return;
    }

    while (_scheduleOverrideAutosaveQueued) {
      _scheduleOverrideAutosaveQueued = false;

      final snapshot = _snapshotForMonth(_selectedMonth) ?? _snapshot;
      if (snapshot == null) {
        return;
      }

      final endTimeText = _persistableScheduleOverrideEndTimeText;
      final draftValidation = validateScheduleDraft(
        targetText: _scheduleOverrideTargetController.text,
        startTimeText: _scheduleOverrideStartTimeController.text,
        endTimeText: endTimeText,
        breakText: _scheduleOverrideBreakController.text,
      );
      final draftSchedule = _parseDayScheduleInput(
        targetText: _scheduleOverrideTargetController.text,
        startTimeText: _scheduleOverrideStartTimeController.text,
        endTimeText: endTimeText,
        breakText: _scheduleOverrideBreakController.text,
      );
      if (draftValidation != null || draftSchedule == null) {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
        continue;
      }

      final baseSchedule = _resolveBaseDayScheduleForDate(
        snapshot,
        _selectedDate,
      );
      final selectedOverride = _findScheduleOverrideForDate(
        snapshot,
        _selectedDate,
      );
      final autosaveAction = _sameDaySchedule(draftSchedule, baseSchedule)
          ? (selectedOverride == null
                ? _ScheduleOverrideAutosaveAction.none
                : _ScheduleOverrideAutosaveAction.remove)
          : _ScheduleOverrideAutosaveAction.save;
      assert(() {
        debugPrint(
          '[agenda-autosave] action=$autosaveAction date=${DashboardService.defaultEntryDateOf(_selectedDate)} '
          'start=${draftSchedule.startTime ?? '-'} end=${draftSchedule.endTime ?? '-'} '
          'target=${draftSchedule.targetMinutes} break=${draftSchedule.breakMinutes}',
        );
        return true;
      }());
      if (autosaveAction == _ScheduleOverrideAutosaveAction.none) {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
        continue;
      }

      if (mounted) {
        setState(() {
          _isSavingScheduleOverride = true;
          _errorMessage = null;
        });
      }

      try {
        final currentPauseWindow = _selectedDayPauseWindowDraft();
        final nextSnapshot =
            autosaveAction == _ScheduleOverrideAutosaveAction.remove
            ? await widget.dashboardService.removeScheduleOverride(
                date: DashboardService.defaultEntryDateOf(_selectedDate),
              )
            : await widget.dashboardService.saveScheduleOverride(
                date: DashboardService.defaultEntryDateOf(_selectedDate),
                targetMinutes: draftSchedule.targetMinutes,
                startTime: draftSchedule.startTime,
                endTime: draftSchedule.endTime,
                breakMinutes: draftSchedule.breakMinutes,
                note: null,
              );

        if (!mounted) {
          return;
        }

        await _cacheSnapshot(nextSnapshot);
        if (!mounted) {
          return;
        }

        _hydrateControllers(
          nextSnapshot,
          _selectedDate,
          resetScheduleHistory: false,
        );
        _setSelectedDayPauseWindowDraft(currentPauseWindow);
        setState(() {
          _snapshot = nextSnapshot;
          _isSavingScheduleOverride = false;
        });
        await _queueCloudBackup();
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage = _humanizeError(error);
          _isSavingScheduleOverride = false;
        });
        return;
      }
    }
  }

  @override
  Future<void> _pickScheduleOverrideTime(CalendarTimeField field) async {
    final initialMinutes = _currentScheduleOverrideTimeMinutes(field);
    final controller = _scheduleTimeController(field);
    final pickedSelection = await _showScheduleTimeWheelPicker(
      title: switch (field) {
        CalendarTimeField.start => 'Entrata',
        CalendarTimeField.end => 'Uscita',
      },
      initialMinutes: initialMinutes,
      allowClear: controller.text.trim().isNotEmpty,
      helperTextBuilder: (pickedMinutes) =>
          _buildScheduleOverrideWorkedMinutesPreviewLabel(
            field: field,
            pickedMinutes: pickedMinutes,
          ),
    );
    if (pickedSelection == null) {
      return;
    }

    _seedScheduleOverrideDraftFromCurrentDisplay();
    if (pickedSelection.cleared) {
      controller.clear();
    } else {
      controller.text = formatTimeInput(pickedSelection.minutes!);
    }
    if (field == CalendarTimeField.start) {
      _syncScheduleOverrideEndFromTarget(
        markPendingConfirmation: widget.appearanceSettings.showDayEndTime,
      );
    } else {
      _clearPendingExitConfirmationForSelectedDate();
    }
    _normalizeSelectedDayPauseWindowForCurrentDraft();
    _clearAgendaPreviewState();
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
    _pushCurrentScheduleOverrideDraftToHistory();
    await _autosaveScheduleOverride();
  }

  String _buildScheduleOverrideWorkedMinutesPreviewLabel({
    required CalendarTimeField field,
    required int pickedMinutes,
  }) {
    final currentSchedule = _displayedScheduleStateForSelectedDate().schedule;
    final minimumBreakMinutes =
        _snapshot?.profile.workRules.minimumBreakMinutes;
    final previewSchedule = _buildFlexibleDayScheduleInput(
      targetText: _scheduleOverrideTargetController.text,
      startTimeText: field == CalendarTimeField.start
          ? formatTimeInput(pickedMinutes)
          : _scheduleOverrideStartTimeController.text,
      endTimeText: field == CalendarTimeField.end
          ? formatTimeInput(pickedMinutes)
          : _scheduleOverrideEndTimeController.text,
      breakText: _scheduleOverrideBreakController.text,
      fallbackSchedule: currentSchedule,
    );
    final workedMinutes = previewSchedule == null
        ? null
        : resolveComputedWorkedMinutes(
            schedule: previewSchedule,
            minimumBreakMinutes: minimumBreakMinutes ?? 0,
          );
    return workedMinutes == null
        ? 'Ore di lavoro: --'
        : 'Ore di lavoro: ${formatHoursInput(workedMinutes)}';
  }

  @override
  Future<void> _pickScheduleOverrideBreakMinutes() async {
    final currentBreakMinutes =
        _displayedScheduleStateForSelectedDate().schedule.breakMinutes;
    final weekday = _weekdayKeyForDate(_selectedDate);
    final pickedMinutes = await _showScheduleBreakWheelPicker(
      initialMinutes: currentBreakMinutes,
      standardScheduleLinkLabel: 'Vai a Orario di lavoro (${weekday.label})',
      onOpenStandardScheduleLink: _openSelectedWeekdayStandardWorkSettings,
    );
    if (pickedMinutes == null) {
      return;
    }
    _seedScheduleOverrideDraftFromCurrentDisplay();
    await _setScheduleOverrideBreakMinutes(pickedMinutes);
  }

  @override
  Future<void> _pickScheduleOverrideTargetMinutes() async {
    final currentTargetMinutes =
        _displayedScheduleStateForSelectedDate().schedule.targetMinutes;
    final weekday = _weekdayKeyForDate(_selectedDate);
    final pickedMinutes = await _showScheduleTargetWheelPicker(
      title: 'Durata del giorno',
      initialMinutes: currentTargetMinutes,
      standardScheduleLinkLabel: 'Vai a Orario di lavoro (${weekday.label})',
      onOpenStandardScheduleLink: _openSelectedWeekdayStandardWorkSettings,
    );
    if (pickedMinutes == null) {
      return;
    }

    _seedScheduleOverrideDraftFromCurrentDisplay();
    _scheduleOverrideTargetController.text = formatHoursInput(pickedMinutes);
    _clearPendingExitConfirmationForSelectedDate();
    final startMinutes = parseTimeInput(
      _scheduleOverrideStartTimeController.text,
    );
    if (startMinutes != null) {
      final breakMinutes =
          parseBreakDurationInput(_scheduleOverrideBreakController.text) ?? 0;
      final targetEndMinutes = startMinutes + pickedMinutes + breakMinutes;
      final normalizedEndMinutes = targetEndMinutes.clamp(0, (23 * 60) + 59);
      _scheduleOverrideEndTimeController.text = formatTimeInput(
        normalizedEndMinutes,
      );
    }
    _normalizeSelectedDayPauseWindowForCurrentDraft();
    _clearAgendaPreviewState();
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
    _pushCurrentScheduleOverrideDraftToHistory();
    await _autosaveScheduleOverride();
  }

  Future<void> _setScheduleOverrideBreakMinutes(int minutes) async {
    final normalizedMinutes = minutes.clamp(0, 24 * 60);
    _scheduleOverrideBreakController.text = formatBreakInput(normalizedMinutes);
    if (_rulesPauseAdjustmentMode ==
        WorkRulesPauseAdjustmentMode.keepWorkedMinutes) {
      _syncScheduleOverrideEndFromTarget(
        markPendingConfirmation: widget.appearanceSettings.showDayEndTime,
      );
    } else {
      final didKeepEndTime = _syncScheduleOverrideTargetFromStartEndAndBreak();
      if (!didKeepEndTime) {
        _syncScheduleOverrideEndFromTarget(
          markPendingConfirmation: widget.appearanceSettings.showDayEndTime,
        );
      }
    }
    _normalizeSelectedDayPauseWindowForCurrentDraft();
    _clearAgendaPreviewState();
    setState(() {
      _errorMessage = null;
    });
    _pushCurrentScheduleOverrideDraftToHistory();
    await _autosaveScheduleOverride();
  }

  bool _syncScheduleOverrideTargetFromStartEndAndBreak() {
    final startMinutes = parseTimeInput(
      _scheduleOverrideStartTimeController.text.trim(),
    );
    final endMinutes = parseTimeInput(
      _scheduleOverrideEndTimeController.text.trim(),
    );
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return false;
    }

    final breakMinutes =
        parseBreakDurationInput(_scheduleOverrideBreakController.text) ?? 0;
    final targetMinutes = math.max(0, endMinutes - startMinutes - breakMinutes);
    _scheduleOverrideTargetController.text = formatHoursInput(targetMinutes);
    _clearPendingExitConfirmationForSelectedDate();
    return true;
  }

  @override
  void _markSelectedDayAsDayOff() {
    _seedScheduleOverrideDraftFromCurrentDisplay();
    _scheduleOverrideTargetController.text = formatHoursInput(0);
    _scheduleOverrideStartTimeController.clear();
    _scheduleOverrideEndTimeController.clear();
    _scheduleOverrideBreakController.clear();
    _setSelectedDayPauseWindowDraft(null);
    _clearPendingExitConfirmationForSelectedDate();
    _clearAgendaPreviewState();
    setState(() {
      _errorMessage = null;
    });
    _pushCurrentScheduleOverrideDraftToHistory();
    unawaited(_autosaveScheduleOverride());
  }

  TextEditingController _scheduleTimeController(CalendarTimeField field) {
    return switch (field) {
      CalendarTimeField.start => _scheduleOverrideStartTimeController,
      CalendarTimeField.end => _scheduleOverrideEndTimeController,
    };
  }

  int _currentScheduleOverrideTimeMinutes(CalendarTimeField field) {
    final fallbackSchedule = _displayedScheduleStateForSelectedDate().schedule;
    final fallbackMinutes = switch (field) {
      CalendarTimeField.start => parseTimeInput(fallbackSchedule.startTime),
      CalendarTimeField.end => parseTimeInput(fallbackSchedule.endTime),
    };
    if (fallbackMinutes != null) {
      return fallbackMinutes;
    }

    if (field == CalendarTimeField.start) {
      return 9 * 60;
    }

    return ((9 * 60) +
            fallbackSchedule.targetMinutes +
            fallbackSchedule.breakMinutes)
        .clamp(0, (23 * 60) + 59);
  }

  @override
  DaySchedule _fallbackScheduleForSelectedDate() {
    final snapshot = _snapshotForMonth(_selectedMonth) ?? _snapshot;
    return snapshot == null
        ? const DaySchedule(targetMinutes: 8 * 60)
        : _resolveEffectiveDayScheduleForDate(snapshot, _selectedDate);
  }

  @override
  void _setSelectedDayPauseWindowDraft(CalendarPauseWindow? pauseWindow) {
    if (pauseWindow == null ||
        pauseWindow.resumeMinutes <= pauseWindow.pauseStartMinutes) {
      _selectedDayPauseStartMinutes = null;
      _selectedDayPauseEndMinutes = null;
      return;
    }

    _selectedDayPauseStartMinutes = pauseWindow.pauseStartMinutes;
    _selectedDayPauseEndMinutes = pauseWindow.resumeMinutes;
  }

  @override
  bool _samePauseWindow(CalendarPauseWindow? left, CalendarPauseWindow? right) {
    return left?.pauseStartMinutes == right?.pauseStartMinutes &&
        left?.resumeMinutes == right?.resumeMinutes;
  }

  @override
  ({DaySchedule schedule, CalendarPauseWindow? pauseWindow})
  _displayedScheduleStateForSelectedDate({
    DashboardSnapshot? snapshot,
    WorkdaySession? session,
  }) {
    final resolvedSnapshot =
        snapshot ?? (_snapshotForMonth(_selectedMonth) ?? _snapshot);
    final effectiveSchedule = resolvedSnapshot == null
        ? const DaySchedule(targetMinutes: 8 * 60)
        : _resolveEffectiveDayScheduleForDate(resolvedSnapshot, _selectedDate);
    final baseSchedule = resolvedSnapshot == null
        ? effectiveSchedule
        : _resolveBaseDayScheduleForDate(resolvedSnapshot, _selectedDate);
    final draftSchedule = _resolveCurrentScheduleDraft(effectiveSchedule);
    final effectiveSession = isSameDay(_selectedDate, _todayDate)
        ? (session ?? _workdaySession)
        : null;
    final displayedSchedule = _resolveDisplayedDayScheduleForSession(
      draftSchedule,
      baseSchedule,
      effectiveSession,
      _selectedDate,
    );
    final pauseWindow = resolveCalendarPauseWindow(
      schedule: displayedSchedule,
      startMinutes: parseTimeInput(displayedSchedule.startTime),
      endMinutes: parseTimeInput(displayedSchedule.endTime),
      session: effectiveSession,
      nowMinutes: _currentMinutesOfDay(),
    );

    return (schedule: displayedSchedule, pauseWindow: pauseWindow);
  }

  @override
  void _seedScheduleOverrideDraftFromCurrentDisplay() {
    final displayedState = _displayedScheduleStateForSelectedDate();
    _primeScheduleOverrideHistoryFromCurrentDisplay();
    _applyDayScheduleDraft(
      displayedState.schedule,
      pauseWindow: displayedState.pauseWindow,
    );
  }

  @override
  void _syncSelectedDayPauseWindowDraftForCurrentDisplay({
    WorkdaySession? session,
  }) {
    final displayedState = _displayedScheduleStateForSelectedDate(
      session: session,
    );
    _setSelectedDayPauseWindowDraft(displayedState.pauseWindow);
  }

  @override
  CalendarPauseWindow? _selectedDayPauseWindowDraft() {
    final pauseStartMinutes = _selectedDayPauseStartMinutes;
    final pauseEndMinutes = _selectedDayPauseEndMinutes;
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
  void _applyDayScheduleDraft(
    DaySchedule schedule, {
    CalendarPauseWindow? pauseWindow,
  }) {
    _clearPendingExitConfirmationForSelectedDate();
    _scheduleOverrideTargetController.text = formatHoursInput(
      schedule.targetMinutes,
    );
    _scheduleOverrideStartTimeController.text = schedule.startTime ?? '';
    _scheduleOverrideEndTimeController.text = schedule.endTime ?? '';
    _scheduleOverrideBreakController.text = formatBreakInput(
      schedule.breakMinutes,
    );
    _setSelectedDayPauseWindowDraft(pauseWindow);
  }

  @override
  void _normalizeSelectedDayPauseWindowForCurrentDraft() {
    final currentSchedule = _resolveCurrentScheduleDraft(
      _fallbackScheduleForSelectedDate(),
    );
    final startMinutes = parseTimeInput(currentSchedule.startTime);
    final endMinutes = parseTimeInput(currentSchedule.endTime);
    final breakMinutes = currentSchedule.breakMinutes;
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes ||
        breakMinutes <= 0) {
      _setSelectedDayPauseWindowDraft(null);
      return;
    }

    final currentPauseWindow = _selectedDayPauseWindowDraft();
    final pauseStartMinutes = currentPauseWindow == null
        ? startMinutes + ((endMinutes - startMinutes - breakMinutes) ~/ 2)
        : (() {
            final currentDuration =
                currentPauseWindow.resumeMinutes -
                currentPauseWindow.pauseStartMinutes;
            final currentCenter =
                currentPauseWindow.pauseStartMinutes + (currentDuration ~/ 2);
            return currentCenter - (breakMinutes ~/ 2);
          })();
    final clampedPauseStartMinutes = pauseStartMinutes.clamp(
      startMinutes,
      endMinutes - breakMinutes,
    );
    _setSelectedDayPauseWindowDraft(
      CalendarPauseWindow(
        pauseStartMinutes: clampedPauseStartMinutes,
        resumeMinutes: clampedPauseStartMinutes + breakMinutes,
      ),
    );
  }

  @override
  CalendarPauseWindow? _resolveSelectedDayPauseWindow({
    required DaySchedule schedule,
    WorkdaySession? session,
  }) {
    final draftPauseWindow = _selectedDayPauseWindowDraft();
    if (draftPauseWindow != null) {
      return draftPauseWindow;
    }

    return resolveCalendarPauseWindow(
      schedule: schedule,
      startMinutes: parseTimeInput(schedule.startTime),
      endMinutes: parseTimeInput(schedule.endTime),
      session: session,
      nowMinutes: _currentMinutesOfDay(),
    );
  }

  @override
  DaySchedule _resolveDisplayedDayScheduleForSession(
    DaySchedule schedule,
    DaySchedule baseSchedule,
    WorkdaySession? session,
    DateTime selectedDate,
  ) {
    if (!isSameDay(selectedDate, _todayDate) || session == null) {
      return schedule;
    }

    final explicitStartMinutes = parseTimeInput(schedule.startTime);
    final explicitEndMinutes = parseTimeInput(schedule.endTime);
    final baseStartMinutes = parseTimeInput(baseSchedule.startTime);
    final baseEndMinutes = parseTimeInput(baseSchedule.endTime);
    final currentBreakMinutes = currentSessionBreakMinutes(
      session,
      _currentMinutesOfDay(),
    );
    final usesDefaultStart =
        explicitStartMinutes == null ||
        (baseStartMinutes != null && explicitStartMinutes == baseStartMinutes);
    final usesDefaultEnd =
        explicitEndMinutes == null ||
        (baseEndMinutes != null && explicitEndMinutes == baseEndMinutes);
    final displayedStartMinutes = usesDefaultStart
        ? session.startMinutes
        : explicitStartMinutes;
    final effectiveBreakMinutes = math.max(
      schedule.breakMinutes,
      currentBreakMinutes,
    );
    final computedEndMinutes = session.endMinutes != null && usesDefaultEnd
        ? session.endMinutes
        : explicitEndMinutes ??
              (schedule.targetMinutes > 0
                  ? displayedStartMinutes +
                        schedule.targetMinutes +
                        effectiveBreakMinutes
                  : null);
    return DaySchedule(
      // Keep daily target stable: editing start/end must not rewrite "Ore di lavoro".
      targetMinutes: schedule.targetMinutes,
      startTime: formatTimeInput(displayedStartMinutes),
      endTime: computedEndMinutes == null
          ? schedule.endTime
          : formatTimeInput(
              (computedEndMinutes % (24 * 60)).clamp(0, (23 * 60) + 59).toInt(),
            ),
      breakMinutes: effectiveBreakMinutes,
    );
  }

  bool _syncScheduleOverrideEndFromTarget({
    bool markPendingConfirmation = false,
  }) {
    final previousEndMinutes = parseTimeInput(
      _scheduleOverrideEndTimeController.text.trim(),
    );
    final startMinutes = parseTimeInput(
      _scheduleOverrideStartTimeController.text,
    );
    final targetMinutes = parseHoursInput(
      _scheduleOverrideTargetController.text,
    );
    final breakMinutes =
        parseBreakDurationInput(_scheduleOverrideBreakController.text) ?? 0;
    if (startMinutes == null || targetMinutes == null) {
      if (markPendingConfirmation) {
        _clearPendingExitConfirmationForSelectedDate();
      }
      return false;
    }

    final endMinutes = (startMinutes + targetMinutes + breakMinutes).clamp(
      0,
      (23 * 60) + 59,
    );
    _scheduleOverrideEndTimeController.text = formatTimeInput(endMinutes);
    if (markPendingConfirmation) {
      if (previousEndMinutes == null || previousEndMinutes != endMinutes) {
        _setPendingExitConfirmationForSelectedDate(endMinutes);
      } else {
        _clearPendingExitConfirmationForSelectedDate();
      }
    } else {
      _clearPendingExitConfirmationForSelectedDate();
    }
    return true;
  }

  @override
  DaySchedule _resolveCurrentScheduleDraft(DaySchedule fallbackSchedule) {
    final draft = _parseDayScheduleInput(
      targetText: _scheduleOverrideTargetController.text,
      startTimeText: _scheduleOverrideStartTimeController.text,
      endTimeText: _scheduleOverrideEndTimeController.text,
      breakText: _scheduleOverrideBreakController.text,
    );
    return draft ?? fallbackSchedule;
  }

  @override
  bool _sameDaySchedule(DaySchedule left, DaySchedule right) {
    return left.targetMinutes == right.targetMinutes &&
        left.startTime == right.startTime &&
        left.endTime == right.endTime &&
        left.breakMinutes == right.breakMinutes;
  }

  @override
  DaySchedule _resolveDisplayedDaySchedule(
    DaySchedule schedule,
    DateTime selectedDate,
  ) {
    final snapshot =
        _snapshotForMonth(DashboardService.formatMonth(selectedDate)) ??
        _snapshot;
    final baseSchedule = snapshot == null
        ? schedule
        : _resolveBaseDayScheduleForDate(snapshot, selectedDate);
    return _resolveDisplayedDayScheduleForSession(
      schedule,
      baseSchedule,
      _workdaySession,
      selectedDate,
    );
  }

  @override
  DayMetrics _withDisplayedDaySchedule(
    DayMetrics metrics,
    DaySchedule displayedSchedule,
  ) {
    return DayMetrics(
      date: metrics.date,
      expectedMinutes: metrics.expectedMinutes,
      workedMinutes: metrics.workedMinutes,
      leaveMinutes: metrics.leaveMinutes,
      rawBalanceMinutes: metrics.rawBalanceMinutes,
      balanceMinutes: metrics.balanceMinutes,
      hasOverride: metrics.hasOverride,
      schedule: displayedSchedule,
      overrideNote: metrics.overrideNote,
    );
  }

  @override
  void _applyPresetMinutes(int minutes) {
    _entryMinutesController.text = minutes.toString();
  }

  @override
  ScheduleOverride? _findScheduleOverrideForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  ) {
    final isoDate = DashboardService.defaultEntryDateOf(date);
    for (final scheduleOverride in snapshot.scheduleOverrides) {
      if (scheduleOverride.date == isoDate) {
        return scheduleOverride;
      }
    }

    return null;
  }

  @override
  DaySchedule _resolveBaseDayScheduleForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  ) {
    return snapshot.profile.weekdaySchedule.forDate(date);
  }

  @override
  DaySchedule _resolveEffectiveDayScheduleForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  ) {
    final scheduleOverride = _findScheduleOverrideForDate(snapshot, date);
    if (scheduleOverride == null) {
      return _resolveBaseDayScheduleForDate(snapshot, date);
    }

    return DaySchedule(
      targetMinutes: scheduleOverride.targetMinutes,
      startTime: scheduleOverride.startTime,
      endTime: scheduleOverride.endTime,
      breakMinutes: scheduleOverride.breakMinutes,
    );
  }

  /// Orario previsto del giorno, completo di entrata e uscita anche quando il
  /// piano dichiara solo le ore.
  ///
  /// Serve solo a mostrare valori gia' impostati: non entra nei calcoli di ore
  /// lavorate e saldi, che devono restare legati a cio' che e' successo davvero.
  @override
  DaySchedule _resolvePlannedDayScheduleForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  ) {
    return completePlannedDaySchedule(
      _resolveEffectiveDayScheduleForDate(snapshot, date),
      referenceStartMinutes: resolvePlannedStartMinutes(
        snapshot.profile.weekdaySchedule,
      ),
    );
  }
}
