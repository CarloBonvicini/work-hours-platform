// Timbratura del giorno: entrata, pausa, uscita, promemoria e conferma uscita.

part of '../home_screen.dart';

mixin _WorkdaySessionState on _HomeScreenStateBase {
  @override
  Future<void> _loadWorkdaySessionForDate(DateTime date) async {
    final isoDate = DashboardService.defaultEntryDateOf(date);
    final session = await widget.workdayStartStore.loadSession(isoDate);
    if (!mounted || !isSameDay(_selectedDate, date)) {
      return;
    }

    setState(() {
      _workdaySession = session;
      _syncSelectedDayPauseWindowDraftForCurrentDisplay(session: session);
    });
  }

  void _startLiveWorkedMinutesTicker() {
    _liveWorkedMinutesTimer?.cancel();
    _liveWorkedMinutesTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _selectedSection != HomeSection.day) {
        return;
      }
      setState(() {});
    });
  }

  void _rescheduleMissingExitReminderForSession(WorkdaySession session) {
    final todayMonth = DashboardService.formatMonth(_todayDate);
    final snapshot = _snapshotForMonth(todayMonth) ?? _snapshot;
    if (snapshot == null) {
      return;
    }

    final schedule = _resolveEffectiveDayScheduleForDate(snapshot, _todayDate);
    if (schedule.targetMinutes <= 0) {
      return;
    }

    final nowMinutes = _currentMinutesOfDay();
    final expectedEndMinutes = resolveSessionExpectedExitMinutes(
      session: session,
      schedule: schedule,
      nowMinutes: nowMinutes,
    );
    unawaited(
      _localNotificationService.scheduleMissingExitReminder(
        // Un'ora di margine oltre l'uscita prevista prima del promemoria.
        delay: Duration(minutes: (expectedEndMinutes + 60) - nowMinutes),
        expectedEndLabel: formatTimeInput(expectedEndMinutes % (24 * 60)),
      ),
    );
  }

  void _scheduleBreakEndReminderForSession(WorkdaySession session) {
    final todayMonth = DashboardService.formatMonth(_todayDate);
    final snapshot = _snapshotForMonth(todayMonth) ?? _snapshot;
    if (snapshot == null) {
      return;
    }

    final schedule = _resolveEffectiveDayScheduleForDate(snapshot, _todayDate);
    final remainingBreakMinutes =
        schedule.breakMinutes - session.accumulatedBreakMinutes;
    if (remainingBreakMinutes <= 0) {
      return;
    }

    unawaited(
      _localNotificationService.scheduleBreakEndReminder(
        delay: Duration(minutes: remainingBreakMinutes),
      ),
    );
  }

  void _cancelWorkdayReminders() {
    unawaited(_localNotificationService.cancelBreakEndReminder());
    unawaited(_localNotificationService.cancelMissingExitReminder());
  }

  /// Su una giornata gia' chiusa l'entrata riapre la sessione: il tempo tra
  /// l'uscita e adesso diventa una pausa, cosi' non si perde nulla di quanto
  /// registrato. Altrimenti inizia una sessione nuova.
  (WorkdaySession, String) _sessionForRecordedStart({
    required WorkdaySession? current,
    required int startMinutes,
  }) {
    final previousEndMinutes = current?.endMinutes;
    if (current == null || previousEndMinutes == null) {
      return (
        WorkdaySession(startMinutes: startMinutes),
        'Entrata registrata alle ${formatTimeInput(startMinutes)}.',
      );
    }

    final awayMinutes = math.max(0, startMinutes - previousEndMinutes);
    final reopened = current.copyWith(
      endMinutes: null,
      accumulatedBreakMinutes: current.accumulatedBreakMinutes + awayMinutes,
      breakSegments: awayMinutes > 0
          ? [
              ...current.breakSegments,
              WorkdayBreakSegment(
                startMinutes: previousEndMinutes,
                endMinutes: startMinutes,
              ),
            ]
          : current.breakSegments,
    );
    final pauseLabel = awayMinutes > 0
        ? ' Pausa ${formatTimeInput(previousEndMinutes)}-${formatTimeInput(startMinutes)} aggiunta.'
        : '';
    return (
      reopened,
      'Rientro registrato alle ${formatTimeInput(startMinutes)}.$pauseLabel',
    );
  }

  @override
  Future<void> _recordWorkdayStartNow() async {
    if (!isSameDay(_selectedDate, _todayDate)) {
      return;
    }

    final now = DateTime.now();
    final startMinutes = (now.hour * 60) + now.minute;
    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);

    setState(() {
      _isSavingWorkdaySession = true;
    });

    try {
      final (session, message) = _sessionForRecordedStart(
        current: _workdaySession,
        startMinutes: startMinutes,
      );
      await widget.workdayStartStore.saveSession(isoDate, session);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = session;
        _syncSelectedDayPauseWindowDraftForCurrentDisplay(session: session);
        _isSavingWorkdaySession = false;
      });
      _rescheduleMissingExitReminderForSession(session);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingWorkdaySession = false;
        _errorMessage = 'Impossibile registrare l entrata in questo momento.';
      });
    }
  }

  @override
  Future<void> _startWorkdayBreakNow() async {
    final session = _workdaySession;
    if (!isSameDay(_selectedDate, _todayDate) ||
        session == null ||
        session.isOnBreak ||
        session.isCompleted) {
      return;
    }

    final now = DateTime.now();
    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);
    setState(() {
      _isSavingWorkdaySession = true;
    });

    try {
      final updatedSession = session.copyWith(
        breakStartedMinutes: (now.hour * 60) + now.minute,
      );
      await widget.workdayStartStore.saveSession(isoDate, updatedSession);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = updatedSession;
        _syncSelectedDayPauseWindowDraftForCurrentDisplay(
          session: updatedSession,
        );
        _isSavingWorkdaySession = false;
      });
      _scheduleBreakEndReminderForSession(updatedSession);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingWorkdaySession = false;
        _errorMessage = 'Impossibile avviare la pausa in questo momento.';
      });
    }
  }

  @override
  Future<void> _resumeWorkdayNow() async {
    final session = _workdaySession;
    final breakStartedMinutes = session?.breakStartedMinutes;
    if (!isSameDay(_selectedDate, _todayDate) ||
        session == null ||
        breakStartedMinutes == null ||
        session.isCompleted) {
      return;
    }

    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);
    setState(() {
      _isSavingWorkdaySession = true;
    });

    try {
      final addedBreakMinutes = math.max(0, nowMinutes - breakStartedMinutes);
      final updatedSession = session.copyWith(
        breakStartedMinutes: null,
        accumulatedBreakMinutes:
            session.accumulatedBreakMinutes + addedBreakMinutes,
        breakSegments: [
          ...session.breakSegments,
          WorkdayBreakSegment(
            startMinutes: breakStartedMinutes,
            endMinutes: nowMinutes,
          ),
        ],
      );
      await widget.workdayStartStore.saveSession(isoDate, updatedSession);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = updatedSession;
        _syncSelectedDayPauseWindowDraftForCurrentDisplay(
          session: updatedSession,
        );
        _isSavingWorkdaySession = false;
      });
      unawaited(_localNotificationService.cancelBreakEndReminder());
      _rescheduleMissingExitReminderForSession(updatedSession);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingWorkdaySession = false;
        _errorMessage = 'Impossibile riprendere la giornata in questo momento.';
      });
    }
  }

  @override
  Future<void> _finishWorkdayNow() async {
    final session = _workdaySession;
    if (!isSameDay(_selectedDate, _todayDate) ||
        session == null ||
        session.isCompleted) {
      return;
    }

    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);
    setState(() {
      _isSavingWorkdaySession = true;
    });

    try {
      final totalBreakMinutes = session.breakStartedMinutes == null
          ? session.accumulatedBreakMinutes
          : session.accumulatedBreakMinutes +
                    math.max(0, nowMinutes - session.breakStartedMinutes!)
                as int;
      final completedBreakSegments = session.breakStartedMinutes == null
          ? session.breakSegments
          : [
              ...session.breakSegments,
              WorkdayBreakSegment(
                startMinutes: session.breakStartedMinutes!,
                endMinutes: nowMinutes,
              ),
            ];
      final updatedSession = session.copyWith(
        breakStartedMinutes: null,
        accumulatedBreakMinutes: totalBreakMinutes,
        breakSegments: completedBreakSegments,
        endMinutes: nowMinutes,
      );
      await widget.workdayStartStore.saveSession(isoDate, updatedSession);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = updatedSession;
        _syncSelectedDayPauseWindowDraftForCurrentDisplay(
          session: updatedSession,
        );
        _isSavingWorkdaySession = false;
      });
      _cancelWorkdayReminders();
      await _registerWorkedHoursForSession(updatedSession, isoDate);
      unawaited(_queueCloudBackup());
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingWorkdaySession = false;
        _errorMessage = 'Impossibile registrare l uscita in questo momento.';
      });
    }
  }

  /// All'uscita la timbratura diventa un dato durevole: l'orario reale del
  /// giorno (override con entrata, uscita e pausa effettiva, obiettivo
  /// invariato) e la voce "Ore lavorate", creata o aggiornata.
  Future<void> _registerWorkedHoursForSession(
    WorkdaySession session,
    String isoDate,
  ) async {
    final endMinutes = session.endMinutes;
    final snapshot =
        _snapshotForMonth(DashboardService.formatMonth(_todayDate)) ??
        _snapshot;
    if (endMinutes == null || snapshot == null) {
      return;
    }

    final schedule = _resolveEffectiveDayScheduleForDate(snapshot, _todayDate);
    final breakMinutes = math.max(
      schedule.breakMinutes,
      session.accumulatedBreakMinutes,
    );
    final workedMinutes = endMinutes - session.startMinutes - breakMinutes;
    if (workedMinutes <= 0) {
      _showWorkdaySnackBar(
        'Uscita registrata alle ${formatTimeInput(endMinutes)}. '
        'Nessuna ora da registrare.',
      );
      return;
    }

    try {
      await widget.dashboardService.saveScheduleOverride(
        date: isoDate,
        targetMinutes: schedule.targetMinutes,
        startTime: formatTimeInput(session.startMinutes),
        endTime: formatTimeInput(endMinutes),
        breakMinutes: breakMinutes,
        note: _findScheduleOverrideForDate(snapshot, _todayDate)?.note,
      );
      final nextSnapshot = await widget.dashboardService.upsertDayWorkedHours(
        date: isoDate,
        minutes: workedMinutes,
        noteIfNew: 'Timbratura',
      );
      if (!mounted) {
        return;
      }
      _hydrateControllers(nextSnapshot, _selectedDate);
      await _cacheSnapshot(nextSnapshot);
      setState(() {
        _snapshot = nextSnapshot;
        _snapshotCache[nextSnapshot.summary.month] = nextSnapshot;
      });
      _showWorkdaySnackBar(
        'Uscita registrata alle ${formatTimeInput(endMinutes)}. '
        'Ore del giorno: ${formatHoursInput(workedMinutes)}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _humanizeError(error);
      });
    }
  }

  void _showWorkdaySnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Future<void> _clearWorkdaySession() async {
    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);
    setState(() {
      _isSavingWorkdaySession = true;
    });

    try {
      await widget.workdayStartStore.clearSession(isoDate);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = null;
        _syncSelectedDayPauseWindowDraftForCurrentDisplay(session: null);
        _isSavingWorkdaySession = false;
      });
      _cancelWorkdayReminders();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingWorkdaySession = false;
        _errorMessage = 'Impossibile rimuovere la giornata registrata.';
      });
    }
  }

  @override
  Future<void> _confirmSuggestedExitMinutes(int exitMinutes) async {
    final clampedExitMinutes = exitMinutes.clamp(0, (23 * 60) + 59).toInt();
    _scheduleOverrideEndTimeController.text = formatTimeInput(
      clampedExitMinutes,
    );
    _clearPendingExitConfirmationForSelectedDate();
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

  @override
  int _currentMinutesOfDay() {
    final now = DateTime.now();
    return (now.hour * 60) + now.minute;
  }

  @override
  bool get _hasPendingExitConfirmationForSelectedDate =>
      _pendingExitConfirmationDateKey ==
          DashboardService.defaultEntryDateOf(_selectedDate) &&
      _pendingExitConfirmationMinutes != null;

  @override
  int? get _pendingExitConfirmationForSelectedDate =>
      _hasPendingExitConfirmationForSelectedDate
      ? _pendingExitConfirmationMinutes
      : null;

  @override
  void _setPendingExitConfirmationForSelectedDate(int minutes) {
    _pendingExitConfirmationDateKey = DashboardService.defaultEntryDateOf(
      _selectedDate,
    );
    _pendingExitConfirmationMinutes = minutes.clamp(0, (23 * 60) + 59);
  }

  @override
  void _clearPendingExitConfirmationForSelectedDate() {
    final selectedDateKey = DashboardService.defaultEntryDateOf(_selectedDate);
    if (_pendingExitConfirmationDateKey != selectedDateKey &&
        _pendingExitConfirmationMinutes != null) {
      return;
    }
    _pendingExitConfirmationDateKey = null;
    _pendingExitConfirmationMinutes = null;
  }
}
