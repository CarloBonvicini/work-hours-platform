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
      countsInBalance: snapshot.countsInBalance(
        isoDate,
        hasRegistrations: workedMinutes > 0 || leaveMinutes > 0,
      ),
    );
  }

  @override
  List<DayMetrics> _buildWeekMetrics() {
    final firstDay = _firstDayOfWeek(_selectedDate);
    return List.generate(
      7,
      (index) => _buildDayMetrics(addCalendarDays(firstDay, index)),
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
      final hasRegistrations = workedMinutes > 0 || leaveMinutes > 0;
      final countsInBalance = snapshot.countsInBalance(
        isoDate,
        hasRegistrations: hasRegistrations,
      );
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
          countsInBalance: countsInBalance,
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
            // Giorno di lavoro passato che pesa sul saldo senza nulla dentro:
            // e' debito, e il calendario lo deve far vedere.
            needsRegistration:
                relation == CalendarDayRelation.past &&
                countsInBalance &&
                !hasRegistrations &&
                effectiveSchedule.targetMinutes > 0,
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
    // Tutte le voci del giorno, non solo le piu' recenti del mese.
    return _buildAllActivities(
      snapshot,
    ).where((item) => item.date == selectedIsoDate).toList(growable: false);
  }

  @override
  Future<void> _ensureUpcomingWeekData() async {
    final days = List.generate(
      7,
      (index) => addCalendarDays(_todayDate, index),
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

  List<ActivityItem> _buildAllActivities(DashboardSnapshot snapshot) {
    final workItems = snapshot.workEntries.map(
      (entry) => ActivityItem(
        key: 'work-${entry.id}',
        entryId: entry.id,
        kind: ActivityEntryKind.work,
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
        entryId: entry.id,
        kind: ActivityEntryKind.leave,
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
    return items;
  }
}
