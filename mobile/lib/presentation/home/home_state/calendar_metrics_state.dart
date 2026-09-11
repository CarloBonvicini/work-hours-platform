// Metriche derivate per calendario, settimana, anno, promemoria e attivita.

part of '../home_screen.dart';

mixin _CalendarMetricsState on _HomeScreenStateBase {
  @override
  DayMetrics _buildDayMetrics(DateTime date) {
    final month = DashboardService.formatMonth(date);
    final snapshot = _snapshotForMonth(month);
    if (snapshot == null) {
      return DayMetrics.empty(date);
    }

    final isoDate = DashboardService.defaultEntryDateOf(date);
    final effectiveSchedule = _resolveEffectiveDayScheduleForDate(
      snapshot,
      date,
    );
    final override = _findScheduleOverrideForDate(snapshot, date);
    final workedMinutes = _sumWorkedMinutesForDate(snapshot, isoDate);
    final leaveMinutes = _sumLeaveMinutesForDate(snapshot, isoDate);
    final rawBalanceMinutes =
        workedMinutes + leaveMinutes - effectiveSchedule.targetMinutes;

    return DayMetrics(
      date: date,
      expectedMinutes: effectiveSchedule.targetMinutes,
      workedMinutes: workedMinutes,
      leaveMinutes: leaveMinutes,
      rawBalanceMinutes: rawBalanceMinutes,
      balanceMinutes: snapshot.profile.workRules.clampDailyBalance(
        rawBalanceMinutes,
      ),
      hasOverride: override != null,
      schedule: effectiveSchedule,
      overrideNote: override?.note,
    );
  }

  @override
  List<DayMetrics> _buildWeekMetrics() {
    final firstDay = _firstDayOfWeek(_selectedDate);
    return List.generate(
      7,
      (index) => _buildDayMetrics(firstDay.add(Duration(days: index))),
      growable: false,
    );
  }

  @override
  List<MonthMetrics> _buildYearMetrics() {
    return List.generate(12, (index) {
      final month =
          '${_selectedDate.year}-${(index + 1).toString().padLeft(2, '0')}';
      final snapshot = _snapshotForMonth(month);
      if (snapshot == null) {
        return MonthMetrics.empty(month);
      }

      return MonthMetrics(
        month: snapshot.summary.month,
        expectedMinutes: snapshot.summary.expectedMinutes,
        workedMinutes: snapshot.summary.workedMinutes,
        leaveMinutes: snapshot.summary.leaveMinutes,
        rawBalanceMinutes: snapshot.summary.rawBalanceMinutes,
        balanceMinutes: snapshot.summary.balanceMinutes,
        overrideCount: _overrideCountForMonth(snapshot),
      );
    }, growable: false);
  }

  @override
  List<CalendarDay> _buildCalendarDays(DashboardSnapshot snapshot) {
    final monthDate = monthToDate(snapshot.summary.month);
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final workMinutesByDate = <String, int>{};
    final leaveMinutesByDate = <String, int>{};

    for (final entry in snapshot.workEntries) {
      workMinutesByDate.update(
        entry.date,
        (value) => value + entry.minutes,
        ifAbsent: () => entry.minutes,
      );
    }

    for (final entry in snapshot.leaveEntries) {
      leaveMinutesByDate.update(
        entry.date,
        (value) => value + entry.minutes,
        ifAbsent: () => entry.minutes,
      );
    }

    final days = <CalendarDay>[];
    for (var index = 1; index < firstDayOfMonth.weekday; index += 1) {
      days.add(const CalendarDay.empty());
    }

    final today = DateTime.now();
    for (var day = 1; day <= daysInMonth; day += 1) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      final isoDate = DashboardService.defaultEntryDateOf(date);
      final effectiveSchedule = _resolveEffectiveDayScheduleForDate(
        snapshot,
        date,
      );
      final displayedSchedule = _resolveDisplayedDaySchedule(
        effectiveSchedule,
        date,
      );
      final hasOverride = _findScheduleOverrideForDate(snapshot, date) != null;
      final relation = switch (compareDateToToday(date)) {
        0 => CalendarDayRelation.today,
        < 0 => CalendarDayRelation.past,
        _ => CalendarDayRelation.future,
      };
      final workedMinutes = workMinutesByDate[isoDate] ?? 0;
      final leaveMinutes = leaveMinutesByDate[isoDate] ?? 0;
      final todayStatusLabel = relation == CalendarDayRelation.today
          ? workdaySessionStatusLabel(
              resolveWorkdaySessionStatus(_workdaySession),
            )
          : null;
      days.add(
        CalendarDay(
          date: date,
          isoDate: isoDate,
          expectedMinutes: effectiveSchedule.targetMinutes,
          workedMinutes: workedMinutes,
          leaveMinutes: leaveMinutes,
          hasOverride: hasOverride,
          isToday: isSameDay(date, today),
          isSelected: isSameDay(date, _selectedDate),
          relation: relation,
          primaryLabel: buildCalendarDayPrimaryLabel(
            relation: relation,
            schedule: displayedSchedule,
            workedMinutes: workedMinutes,
            leaveMinutes: leaveMinutes,
            hasOverride: hasOverride,
          ),
          secondaryLabel: buildCalendarDaySecondaryLabel(
            relation: relation,
            workedMinutes: workedMinutes,
            leaveMinutes: leaveMinutes,
            hasOverride: hasOverride,
            todayStatusLabel: todayStatusLabel,
          ),
          details: buildCalendarDayDetails(
            relation: relation,
            schedule: displayedSchedule,
            workedMinutes: workedMinutes,
            leaveMinutes: leaveMinutes,
            session: relation == CalendarDayRelation.today
                ? _workdaySession
                : null,
          ),
        ),
      );
    }

    while (days.length % 7 != 0) {
      days.add(const CalendarDay.empty());
    }

    return days;
  }

  @override
  List<ActivityItem> _buildActivitiesForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  ) {
    final selectedIsoDate = DashboardService.defaultEntryDateOf(date);
    return _buildActivities(
      snapshot,
    ).where((item) => item.date == selectedIsoDate).toList(growable: false);
  }

  TodayStatus _resolveDayStatus(DateTime date, DayMetrics metrics) {
    final registeredMinutes = metrics.workedMinutes + metrics.leaveMinutes;
    if (metrics.expectedMinutes == 0 && registeredMinutes == 0) {
      return TodayStatus.dayOff;
    }
    if (metrics.leaveMinutes >= metrics.expectedMinutes &&
        metrics.expectedMinutes > 0) {
      return TodayStatus.absent;
    }
    if (registeredMinutes >= metrics.expectedMinutes &&
        metrics.expectedMinutes > 0) {
      return TodayStatus.completed;
    }

    final now = DateTime.now();
    final currentMinutesOfDay = (now.hour * 60) + now.minute;
    final scheduledStart = parseTimeInput(metrics.schedule.startTime);
    final scheduledEnd = parseTimeInput(metrics.schedule.endTime);

    if (date.isAfter(_todayDate)) {
      return TodayStatus.planned;
    }

    if (date.isBefore(_todayDate)) {
      return registeredMinutes == 0
          ? TodayStatus.needsAttention
          : TodayStatus.inProgress;
    }

    if (registeredMinutes == 0) {
      if (scheduledStart != null && currentMinutesOfDay < scheduledStart) {
        return TodayStatus.planned;
      }
      return TodayStatus.needsAttention;
    }

    if (scheduledEnd != null && currentMinutesOfDay >= scheduledEnd + 15) {
      return TodayStatus.needsAttention;
    }

    return TodayStatus.inProgress;
  }

  @override
  TodayStatus _resolveTodayStatus(DayMetrics metrics) {
    return _resolveDayStatus(_todayDate, metrics);
  }

  @override
  List<({IconData icon, String title, String description})>
  _buildTodayReminders(DashboardSnapshot snapshot, DayMetrics metrics) {
    final reminders = <({IconData icon, String title, String description})>[];
    final todayStatus = _resolveTodayStatus(metrics);
    final now = DateTime.now();
    final currentMinutesOfDay = (now.hour * 60) + now.minute;
    final scheduledStart = parseTimeInput(metrics.schedule.startTime);
    final scheduledEnd = parseTimeInput(metrics.schedule.endTime);

    if (todayStatus == TodayStatus.needsAttention &&
        scheduledStart != null &&
        currentMinutesOfDay >= scheduledStart) {
      reminders.add((
        icon: Icons.play_circle_outline,
        title: 'Giornata da avviare o chiudere',
        description:
            'Oggi risulti ancora incompleto. Registra le ore mancanti oppure chiudi la giornata.',
      ));
    }

    if (todayStatus == TodayStatus.inProgress &&
        scheduledEnd != null &&
        currentMinutesOfDay >= scheduledEnd - 30) {
      reminders.add((
        icon: Icons.alarm_on_outlined,
        title: 'Controlla la chiusura di oggi',
        description:
            'La fascia prevista sta per finire. Ti conviene verificare l ultima registrazione della giornata.',
      ));
    }

    final tomorrow = _todayDate.add(const Duration(days: 1));
    final tomorrowSnapshot =
        _snapshotForMonth(DashboardService.formatMonth(tomorrow)) ??
        (isSameMonth(tomorrow, monthToDate(snapshot.summary.month))
            ? snapshot
            : null);
    final tomorrowOverride = tomorrowSnapshot == null
        ? null
        : _findScheduleOverrideForDate(tomorrowSnapshot, tomorrow);
    if (tomorrowOverride != null) {
      reminders.add((
        icon: Icons.event_repeat_outlined,
        title: 'Domani hai orari diversi',
        description:
            'Il programma di domani e diverso dal solito. Controlla gli orari prima di iniziare.',
      ));
    }

    if (metrics.hasOverride) {
      reminders.add((
        icon: Icons.rule_folder_outlined,
        title: 'Oggi hai orari diversi',
        description:
            'La giornata di oggi usa orari diversi rispetto al solito.',
      ));
    }

    return reminders;
  }

  @override
  Future<void> _ensureUpcomingWeekData() async {
    final days = List.generate(
      7,
      (index) => _todayDate.add(Duration(days: index)),
      growable: false,
    );
    final missingMonths = days
        .map(DashboardService.formatMonth)
        .where((month) => !_snapshotCache.containsKey(month))
        .toSet()
        .toList(growable: false);
    if (missingMonths.isEmpty) {
      return;
    }

    try {
      for (final month in missingMonths) {
        final loadedSnapshot = await widget.dashboardService.loadSnapshot(
          month: month,
        );
        await _cacheSnapshot(loadedSnapshot);
      }
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _humanizeError(error);
        });
      }
    }
  }

  @override
  List<WeekPlanDay> _buildUpcomingWeekPlan() {
    return List.generate(7, (index) {
      final date = _todayDate.add(Duration(days: index));
      final month = DashboardService.formatMonth(date);
      final monthSnapshot = _snapshotForMonth(month);
      if (monthSnapshot == null) {
        return WeekPlanDay.empty(date);
      }

      final metrics = _buildDayMetrics(date);
      final override = _findScheduleOverrideForDate(monthSnapshot, date);
      return WeekPlanDay(
        date: date,
        status: _resolveDayStatus(date, metrics),
        metrics: metrics,
        overrideNote: override?.note,
      );
    }, growable: false);
  }

  List<ActivityItem> _buildActivities(DashboardSnapshot snapshot) {
    final workItems = snapshot.workEntries.map(
      (entry) => ActivityItem(
        key: 'work-${entry.id}',
        date: entry.date,
        title: 'Ore lavorate',
        subtitle: entry.note?.isNotEmpty == true
            ? entry.note!
            : 'Registrazione lavoro',
        minutes: entry.minutes,
        accentColor: const Color(0xFF0B6E69),
        icon: Icons.work_outline,
      ),
    );

    final leaveItems = snapshot.leaveEntries.map(
      (entry) => ActivityItem(
        key: 'leave-${entry.id}',
        date: entry.date,
        title: entry.type.label,
        subtitle: entry.note?.isNotEmpty == true
            ? entry.note!
            : 'Assenza registrata',
        minutes: entry.minutes,
        accentColor: const Color(0xFFBF7A24),
        icon: entry.type == LeaveType.vacation
            ? Icons.beach_access_outlined
            : Icons.event_available_outlined,
      ),
    );

    final items = [...workItems, ...leaveItems];
    items.sort((left, right) => right.date.compareTo(left.date));
    return items.take(8).toList(growable: false);
  }
}
