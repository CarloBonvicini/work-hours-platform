// Navigazione di calendario: data/mese/vista selezionati e caricamento mesi.

part of '../home_screen.dart';

mixin _CalendarNavigationState on _HomeScreenStateBase {
  @override
  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Future<void> _openDayForDate(DateTime date) async {
    setState(() {
      _goToSection(HomeSection.day);
    });
    await _setSelectedDate(date, alignToPeriod: false);
  }

  @override
  Future<void> _shiftSelectedDay(int step) async {
    await _setSelectedDate(
      addCalendarDays(_selectedDate, step),
      alignToPeriod: false,
    );
  }

  @override
  Future<DashboardSnapshot> _fetchSnapshotForMonth(
    String month, {
    bool forceReload = false,
  }) async {
    // Con forceReload si ignorano memoria e cache persistita: serve quando i
    // dati sono cambiati fuori dal flusso normale (ripristino cloud, riprova).
    if (!forceReload) {
      final currentSnapshot = _snapshot;
      if (currentSnapshot != null && currentSnapshot.summary.month == month) {
        _snapshotCache[month] = currentSnapshot;
        return currentSnapshot;
      }

      final cachedSnapshot = _snapshotCache[month];
      if (cachedSnapshot != null) {
        return cachedSnapshot;
      }

      final persistedSnapshot = await widget.dashboardSnapshotStore
          .loadSnapshot(month);
      if (persistedSnapshot != null) {
        _snapshotCache[month] = persistedSnapshot;
        return persistedSnapshot;
      }
    }

    final snapshot = await widget.dashboardService.loadSnapshot(month: month);
    await _cacheSnapshot(snapshot);
    return snapshot;
  }

  @override
  Future<void> _ensureCalendarDataForCurrentView() async {
    final months = _requiredMonthsForCalendarView();
    final missingMonths = months
        .where((month) => !_snapshotCache.containsKey(month))
        .toList(growable: false);
    if (missingMonths.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _isLoadingCalendarData = true;
    });

    try {
      for (final month in missingMonths) {
        final snapshot = await widget.dashboardService.loadSnapshot(
          month: month,
        );
        await _cacheSnapshot(snapshot);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _humanizeError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCalendarData = false;
        });
      }
    }
  }

  @override
  Future<void> _changeCalendarView(CalendarView view) async {
    if (_calendarView == view) {
      return;
    }

    setState(() {
      _calendarView = view;
    });
    await _ensureCalendarDataForCurrentView();
  }

  @override
  Future<void> _shiftCalendarPeriod(int step) async {
    final nextDate = shiftCalendarPeriodDate(
      _selectedDate,
      _calendarView,
      step,
    );

    await _setSelectedDate(nextDate, alignToPeriod: true);
  }

  Future<void> _setSelectedDate(
    DateTime date, {
    bool alignToPeriod = false,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextSelectedDate = switch (_calendarView) {
      CalendarView.month when alignToPeriod => DateTime(
        normalizedDate.year,
        normalizedDate.month,
        1,
      ),
      CalendarView.year when alignToPeriod => DateTime(
        normalizedDate.year,
        normalizedDate.month,
        1,
      ),
      _ => normalizedDate,
    };

    _entryDateController.text = DashboardService.defaultEntryDateOf(
      nextSelectedDate,
    );
    final nextMonth = DashboardService.formatMonth(nextSelectedDate);
    if (nextMonth != _selectedMonth) {
      await _loadSnapshot(month: nextMonth, selectedDate: nextSelectedDate);
      return;
    }

    setState(() {
      _selectedDate = nextSelectedDate;
      _workdaySession = null;
      _clearAgendaPreviewState();
    });
    unawaited(_loadWorkdaySessionForDate(nextSelectedDate));
    final currentSnapshot = _snapshot;
    if (currentSnapshot != null) {
      _hydrateSelectedDateControllers(currentSnapshot, nextSelectedDate);
    }
    await _ensureCalendarDataForCurrentView();
  }

  @override
  void _selectDate(DateTime date) {
    unawaited(_setSelectedDate(date));
  }

  @override
  void _hydrateSelectedDateControllers(
    DashboardSnapshot snapshot,
    DateTime selectedDate, {
    bool resetScheduleHistory = true,
  }) {
    final daySchedule = _resolveEffectiveDayScheduleForDate(
      snapshot,
      selectedDate,
    );
    final baseSchedule = _resolveBaseDayScheduleForDate(snapshot, selectedDate);
    final displayedSchedule = _resolveDisplayedDayScheduleForSession(
      daySchedule,
      baseSchedule,
      isSameDay(selectedDate, _todayDate) ? _workdaySession : null,
      selectedDate,
    );
    final displayedPauseWindow = resolveCalendarPauseWindow(
      schedule: displayedSchedule,
      startMinutes: parseTimeInput(displayedSchedule.startTime),
      endMinutes: parseTimeInput(displayedSchedule.endTime),
      session: isSameDay(selectedDate, _todayDate) ? _workdaySession : null,
      nowMinutes: _currentMinutesOfDay(),
    );
    _applyDayScheduleDraft(daySchedule, pauseWindow: displayedPauseWindow);
    if (resetScheduleHistory) {
      _resetScheduleOverrideHistoryForDate(
        selectedDate,
        schedule: displayedSchedule,
        pauseWindow: displayedPauseWindow,
      );
    }
  }

  @override
  DashboardSnapshot? _snapshotForMonth(String month) {
    final currentSnapshot = _snapshot;
    if (currentSnapshot != null && currentSnapshot.summary.month == month) {
      return currentSnapshot;
    }

    return _snapshotCache[month];
  }

  List<String> _requiredMonthsForCalendarView() {
    switch (_calendarView) {
      case CalendarView.day:
      case CalendarView.month:
        return [DashboardService.formatMonth(_selectedDate)];
      case CalendarView.week:
        return _monthsBetweenDates(
          _firstDayOfWeek(_selectedDate),
          _lastDayOfWeek(_selectedDate),
        );
      case CalendarView.year:
        return List.generate(
          12,
          (index) =>
              '${_selectedDate.year}-${(index + 1).toString().padLeft(2, '0')}',
        );
    }
  }

  List<String> _monthsBetweenDates(DateTime start, DateTime end) {
    final months = <String>[];
    var cursor = DateTime(start.year, start.month, 1);
    final lastMonth = DateTime(end.year, end.month, 1);

    while (!cursor.isAfter(lastMonth)) {
      months.add(DashboardService.formatMonth(cursor));
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return months;
  }

  @override
  DateTime _firstDayOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday - 1));
  }

  DateTime _lastDayOfWeek(DateTime date) {
    final firstDay = _firstDayOfWeek(date);
    return addCalendarDays(firstDay, 6);
  }

  String _calendarPeriodLabelFor(CalendarView view) {
    switch (view) {
      case CalendarView.day:
        return formatLongDate(_selectedDate);
      case CalendarView.week:
        final firstDay = _firstDayOfWeek(_selectedDate);
        final lastDay = _lastDayOfWeek(_selectedDate);
        return '${formatCompactDate(firstDay)} - ${formatCompactDate(lastDay)}';
      case CalendarView.month:
        return formatMonthLabel(_selectedMonth);
      case CalendarView.year:
        return '${_selectedDate.year}';
    }
  }

  @override
  String _calendarPeriodLabel() => _calendarPeriodLabelFor(_calendarView);

  @override
  DateTime _resolveSelectedDateForMonth(
    String month, {
    DateTime? preferredDate,
  }) {
    final monthDate = monthToDate(month);
    final candidateDate = preferredDate;
    if (candidateDate != null && isSameMonth(candidateDate, monthDate)) {
      return DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
      );
    }

    if (_snapshot != null && isSameMonth(_selectedDate, monthDate)) {
      return DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
    }

    final today = DateTime.now();
    if (isSameMonth(today, monthDate)) {
      return DateTime(today.year, today.month, today.day);
    }

    return DateTime(monthDate.year, monthDate.month, 1);
  }
}
