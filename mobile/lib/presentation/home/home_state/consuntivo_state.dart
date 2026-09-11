// Dati e navigazione della sezione Consuntivo.

part of '../home_screen.dart';

mixin _ConsuntivoState on _HomeScreenStateBase {
  List<String> _requiredMonthsForConsuntivoRange() {
    final monthCount = _consuntivoRange.monthCount;
    final anchorMonthDate = monthToDate(_selectedMonth);

    return List.generate(monthCount, (index) {
      final offset = (monthCount - 1) - index;
      final monthDate = DateTime(
        anchorMonthDate.year,
        anchorMonthDate.month - offset,
        1,
      );
      return DashboardService.formatMonth(monthDate);
    }, growable: false);
  }

  @override
  Future<void> _ensureConsuntivoDataLoaded() async {
    if (!mounted || _isLoadingConsuntivoData) {
      return;
    }

    final requiredMonths = _requiredMonthsForConsuntivoRange();
    final missingMonths = requiredMonths
        .where((month) => _snapshotForMonth(month) == null)
        .toList(growable: false);
    if (missingMonths.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingConsuntivoData = true;
    });

    try {
      for (final month in missingMonths) {
        final snapshot = await _fetchSnapshotForMonth(month);
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
          _isLoadingConsuntivoData = false;
        });
      }
    }
  }

  @override
  Future<void> _changeConsuntivoRange(ConsuntivoRangeOption nextRange) async {
    if (nextRange == _consuntivoRange) {
      return;
    }

    setState(() {
      _consuntivoRange = nextRange;
    });
    await _ensureConsuntivoDataLoaded();
  }

  @override
  Future<void> _shiftConsuntivoAnchorMonth(int step) async {
    if (step == 0 || _isLoading) {
      return;
    }

    final currentMonthDate = monthToDate(_selectedMonth);
    final nextMonthDate = DateTime(
      currentMonthDate.year,
      currentMonthDate.month + step,
      1,
    );
    final nextMonth = DashboardService.formatMonth(nextMonthDate);
    if (nextMonth == _selectedMonth) {
      return;
    }

    final daysInNextMonth = DateTime(
      nextMonthDate.year,
      nextMonthDate.month + 1,
      0,
    ).day;
    final nextSelectedDate = DateTime(
      nextMonthDate.year,
      nextMonthDate.month,
      math.min(_selectedDate.day, daysInNextMonth),
    );

    await _loadSnapshot(month: nextMonth, selectedDate: nextSelectedDate);
    if (!mounted) {
      return;
    }
    await _ensureConsuntivoDataLoaded();
  }

  @override
  ConsuntivoSectionData _buildConsuntivoSectionData(
    DashboardSnapshot fallbackSnapshot,
  ) {
    final requiredMonths = _requiredMonthsForConsuntivoRange();
    final snapshotsByMonth = <String, DashboardSnapshot>{
      for (final month in requiredMonths)
        if (_snapshotForMonth(month) != null) month: _snapshotForMonth(month)!,
    };
    final anchorSnapshot =
        snapshotsByMonth[_selectedMonth] ??
        _snapshotForMonth(_selectedMonth) ??
        fallbackSnapshot;

    final monthSummaries = requiredMonths
        .map((month) {
          final snapshot = snapshotsByMonth[month];
          if (snapshot == null) {
            return ConsuntivoMonthSummary(
              monthLabel: formatMonthLabel(month),
              expectedMinutes: 0,
              workedMinutes: 0,
              leaveMinutes: 0,
              balanceMinutes: 0,
            );
          }

          return ConsuntivoMonthSummary(
            monthLabel: formatMonthLabel(snapshot.summary.month),
            expectedMinutes: snapshot.summary.expectedMinutes,
            workedMinutes: snapshot.summary.workedMinutes,
            leaveMinutes: snapshot.summary.leaveMinutes,
            balanceMinutes: snapshot.summary.balanceMinutes,
          );
        })
        .toList(growable: false);

    var totalExpectedMinutes = 0;
    var totalWorkedMinutes = 0;
    var totalLeaveMinutes = 0;
    var totalRawBalanceMinutes = 0;
    var totalClampedBalanceMinutes = 0;

    for (final month in requiredMonths) {
      final snapshot = snapshotsByMonth[month];
      if (snapshot == null) {
        continue;
      }

      totalExpectedMinutes += snapshot.summary.expectedMinutes;
      totalWorkedMinutes += snapshot.summary.workedMinutes;
      totalLeaveMinutes += snapshot.summary.leaveMinutes;
      totalRawBalanceMinutes += snapshot.summary.rawBalanceMinutes;
      totalClampedBalanceMinutes += snapshot.summary.balanceMinutes;
    }

    final allPermissionRules = [
      ...anchorSnapshot.profile.workRules.additionalPermissions,
      ...anchorSnapshot.profile.workRules.leaveBanks,
    ];
    final permissions =
        allPermissionRules
            .map(
              (rule) => ConsuntivoPermissionSummary(
                name: rule.name,
                periodLabel: rule.period.label,
                enabled: rule.enabled,
                allowanceLabel: formatRuleAllowanceValue(rule),
                usedLabel: formatRuleUsedValue(rule),
                remainingLabel: formatRuleRemainingValue(rule),
                movementsLabel: rule.movements
                    .map((item) => item.label)
                    .join(', '),
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.name.compareTo(right.name));

    final daySummariesData = _buildConsuntivoDaySummaries(
      requiredMonths: requiredMonths,
      snapshotsByMonth: snapshotsByMonth,
    );

    final firstMonthLabel = formatMonthLabel(requiredMonths.first);
    final lastMonthLabel = formatMonthLabel(requiredMonths.last);
    final periodLabel = firstMonthLabel == lastMonthLabel
        ? firstMonthLabel
        : '$firstMonthLabel - $lastMonthLabel';

    return ConsuntivoSectionData(
      anchorMonthLabel: formatMonthLabel(_selectedMonth),
      periodLabel: periodLabel,
      totals: ConsuntivoTotals(
        expectedMinutes: totalExpectedMinutes,
        workedMinutes: totalWorkedMinutes,
        leaveMinutes: totalLeaveMinutes,
        rawBalanceMinutes: totalRawBalanceMinutes,
        clampedBalanceMinutes: totalClampedBalanceMinutes,
        overtimeMaturedMinutes: math.max(totalRawBalanceMinutes, 0),
        debitMaturedMinutes: math.max(-totalRawBalanceMinutes, 0),
      ),
      months: monthSummaries,
      permissions: permissions,
      days: daySummariesData.days,
      hiddenDaysCount: daySummariesData.hiddenCount,
    );
  }

  ({List<ConsuntivoDaySummary> days, int hiddenCount})
  _buildConsuntivoDaySummaries({
    required List<String> requiredMonths,
    required Map<String, DashboardSnapshot> snapshotsByMonth,
  }) {
    if (requiredMonths.isEmpty) {
      return (days: const <ConsuntivoDaySummary>[], hiddenCount: 0);
    }

    final workByMonthAndDate = <String, Map<String, List<WorkEntry>>>{};
    final leaveByMonthAndDate = <String, Map<String, List<LeaveEntry>>>{};
    final overridesByMonthAndDate = <String, Map<String, ScheduleOverride>>{};

    for (final month in requiredMonths) {
      final snapshot = snapshotsByMonth[month];
      if (snapshot == null) {
        continue;
      }

      final workByDate = <String, List<WorkEntry>>{};
      for (final entry in snapshot.workEntries) {
        workByDate.putIfAbsent(entry.date, () => <WorkEntry>[]).add(entry);
      }

      final leaveByDate = <String, List<LeaveEntry>>{};
      for (final entry in snapshot.leaveEntries) {
        leaveByDate.putIfAbsent(entry.date, () => <LeaveEntry>[]).add(entry);
      }

      final overrideByDate = <String, ScheduleOverride>{
        for (final item in snapshot.scheduleOverrides) item.date: item,
      };

      workByMonthAndDate[month] = workByDate;
      leaveByMonthAndDate[month] = leaveByDate;
      overridesByMonthAndDate[month] = overrideByDate;
    }

    final startDate = monthToDate(requiredMonths.first);
    final selectedMonthDate = monthToDate(_selectedMonth);
    final selectedMonthLastDate = DateTime(
      selectedMonthDate.year,
      selectedMonthDate.month + 1,
      0,
    );
    final today = DateUtils.dateOnly(DateTime.now());
    final endDate = selectedMonthLastDate.isAfter(today)
        ? today
        : selectedMonthLastDate;
    if (endDate.isBefore(startDate)) {
      return (days: const <ConsuntivoDaySummary>[], hiddenCount: 0);
    }

    final allDays = <ConsuntivoDaySummary>[];
    var cursor = endDate;
    while (!cursor.isBefore(startDate)) {
      final month = DashboardService.formatMonth(cursor);
      final snapshot = snapshotsByMonth[month];
      if (snapshot != null) {
        final isoDate = DashboardService.defaultEntryDateOf(cursor);
        final workEntries =
            workByMonthAndDate[month]?[isoDate] ?? const <WorkEntry>[];
        final leaveEntries =
            leaveByMonthAndDate[month]?[isoDate] ?? const <LeaveEntry>[];
        final override = overridesByMonthAndDate[month]?[isoDate];
        final effectiveSchedule = _resolveEffectiveDayScheduleForDate(
          snapshot,
          cursor,
        );

        final workedMinutes = workEntries.fold<int>(
          0,
          (total, entry) => total + entry.minutes,
        );
        final leaveMinutes = leaveEntries.fold<int>(
          0,
          (total, entry) => total + entry.minutes,
        );
        final registeredMinutes = workedMinutes + leaveMinutes;
        final balanceMinutes =
            registeredMinutes - effectiveSchedule.targetMinutes;

        final includeRow =
            workedMinutes > 0 ||
            leaveMinutes > 0 ||
            override != null ||
            balanceMinutes != 0;
        if (includeRow) {
          final startTime = effectiveSchedule.startTime?.trim() ?? '';
          final endTime = effectiveSchedule.endTime?.trim() ?? '';
          final hasTimeline = startTime.isNotEmpty && endTime.isNotEmpty;
          final scheduleDetail = hasTimeline
              ? 'Dettaglio: $startTime-$endTime, pausa ${formatHoursInput(effectiveSchedule.breakMinutes)}'
              : null;

          final details = <String>[];
          if (leaveEntries.isNotEmpty) {
            final leaveLabel = leaveEntries
                .map(
                  (entry) =>
                      '${entry.type.label} ${formatHoursInput(entry.minutes)}',
                )
                .join(', ');
            details.add('Causali: $leaveLabel');
          }
          if (override != null) {
            details.add('Programma personalizzato');
          }
          final notedWorkEntries = workEntries
              .map((entry) => entry.note?.trim() ?? '')
              .where((note) => note.isNotEmpty)
              .toList(growable: false);
          if (notedWorkEntries.isNotEmpty) {
            details.add('Note: ${notedWorkEntries.join(' | ')}');
          }

          allDays.add(
            ConsuntivoDaySummary(
              dateLabel:
                  '${formatWeekdayShortLabel(cursor)} ${formatCompactDate(cursor)}',
              plannedLabel: formatHoursInput(effectiveSchedule.targetMinutes),
              registeredLabel: formatHoursInput(registeredMinutes),
              balanceMinutes: balanceMinutes,
              scheduleDetail: scheduleDetail,
              causalDetail: details.isEmpty ? null : details.join(' | '),
            ),
          );
        }
      }

      cursor = cursor.subtract(const Duration(days: 1));
    }

    const maxVisibleRows = 90;
    if (allDays.length <= maxVisibleRows) {
      return (days: allDays, hiddenCount: 0);
    }

    return (
      days: allDays.take(maxVisibleRows).toList(growable: false),
      hiddenCount: allDays.length - maxVisibleRows,
    );
  }
}
