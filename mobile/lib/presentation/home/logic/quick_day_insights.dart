// Saldi visualizzati (mese/periodo) e controlli sui limiti per l'editor rapido del giorno.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';

class DisplayedMonthBalanceInfo {
  const DisplayedMonthBalanceInfo({required this.value});

  final String value;
}

class DisplayedPeriodBalanceInfo {
  const DisplayedPeriodBalanceInfo({required this.balanceMinutes});

  final int balanceMinutes;
}

class QuickDayControlInsights {
  const QuickDayControlInsights({
    required this.controlledBalanceMinutes,
    required this.todayOvertimeMinutes,
    required this.exceededOvertimeMinutes,
    required this.showConfigurationHint,
    this.limitWarningText,
    this.configurationHint,
  });

  final int controlledBalanceMinutes;
  final int todayOvertimeMinutes;
  final int exceededOvertimeMinutes;
  final bool showConfigurationHint;
  final String? limitWarningText;
  final String? configurationHint;
}

DisplayedMonthBalanceInfo buildDisplayedMonthBalanceInfo({
  required DateTime selectedDate,
  required List<CalendarDay> days,
  required int liveExpectedMinutes,
  required int liveWorkedMinutes,
  required int liveLeaveMinutes,
}) {
  final selectedDay = DateUtils.dateOnly(selectedDate);
  final monthDays = days
      .where((day) => day.date != null)
      .toList(growable: false);
  if (monthDays.isEmpty) {
    return const DisplayedMonthBalanceInfo(value: '0:00');
  }

  var monthWorkedMinutes = 0;
  var monthExpectedMinutes = 0;
  final hasLiveContext = hasRegisteredBalanceContext(
    workedMinutes: liveWorkedMinutes,
    leaveMinutes: liveLeaveMinutes,
  );

  for (final day in monthDays) {
    final date = day.date;
    if (date == null) {
      continue;
    }

    final isSelectedCalendarDay = isSameDay(date, selectedDay);
    monthExpectedMinutes += isSelectedCalendarDay
        ? liveExpectedMinutes
        : day.expectedMinutes;

    if (day.relation == CalendarDayRelation.future && !isSelectedCalendarDay) {
      continue;
    }

    monthWorkedMinutes += isSelectedCalendarDay && hasLiveContext
        ? liveWorkedMinutes
        : day.workedMinutes;
  }

  if (monthExpectedMinutes <= 0) {
    return DisplayedMonthBalanceInfo(
      value: formatHoursInput(monthWorkedMinutes),
    );
  }

  return DisplayedMonthBalanceInfo(
    value:
        '${formatHoursInput(monthWorkedMinutes)} / ${formatHoursInput(monthExpectedMinutes)}',
  );
}

/// Saldo di un giorno dalle sole registrazioni: ore e causali contro il
/// previsto. L'orario scritto su un giorno passato conta perche' diventa una
/// voce di ore, non perche' lo si legge qui: prima questo conto lo leggeva
/// dall'orario, e settimana e consuntivo davano un altro saldo.
int _registeredBalanceMinutes(CalendarDay day) {
  return day.workedMinutes + day.leaveMinutes - day.expectedMinutes;
}

DisplayedPeriodBalanceInfo buildDisplayedPeriodBalanceInfo({
  required DateTime selectedDate,
  required List<CalendarDay> days,
  required List<DayMetrics> weekMetrics,
  required DayBalanceAggregation aggregation,
  required int liveExpectedMinutes,
  required int liveWorkedMinutes,
  required int liveLeaveMinutes,
}) {
  final selectedDay = DateUtils.dateOnly(selectedDate);
  final hasLiveContext = hasRegisteredBalanceContext(
    workedMinutes: liveWorkedMinutes,
    leaveMinutes: liveLeaveMinutes,
  );
  final liveDayBalanceMinutes =
      (liveWorkedMinutes + liveLeaveMinutes) - liveExpectedMinutes;

  switch (aggregation) {
    case DayBalanceAggregation.weekly:
      var hasWeeklyEntries = false;
      final weeklyBalanceMinutes = weekMetrics.fold<int>(0, (total, metric) {
        if (isSameDay(metric.date, selectedDay) && hasLiveContext) {
          hasWeeklyEntries = true;
          return total + liveDayBalanceMinutes;
        }
        // Un giorno passato senza niente registrato pesa come debito.
        if (!metric.countsInBalance) {
          return total;
        }
        hasWeeklyEntries = true;
        return total + metric.rawBalanceMinutes;
      });
      return DisplayedPeriodBalanceInfo(
        balanceMinutes: hasWeeklyEntries ? weeklyBalanceMinutes : 0,
      );
    case DayBalanceAggregation.monthly:
      var monthlyBalanceMinutes = 0;
      var hasMonthlyEntries = false;
      for (final day in days) {
        final date = day.date;
        if (date == null) {
          continue;
        }
        if (day.relation == CalendarDayRelation.future) {
          continue;
        }
        if (isSameDay(date, selectedDay) && hasLiveContext) {
          hasMonthlyEntries = true;
          monthlyBalanceMinutes += liveDayBalanceMinutes;
          continue;
        }
        if (!day.countsInBalance) {
          continue;
        }
        hasMonthlyEntries = true;
        monthlyBalanceMinutes += _registeredBalanceMinutes(day);
      }
      return DisplayedPeriodBalanceInfo(
        balanceMinutes: hasMonthlyEntries ? monthlyBalanceMinutes : 0,
      );
  }
}

bool hasRegisteredBalanceContext({
  required int workedMinutes,
  required int leaveMinutes,
}) {
  return workedMinutes > 0 || leaveMinutes > 0;
}

const int unboundedDailyLimitMinutes = 24 * 60;

const int unboundedMonthlyLimitMinutes = 31 * 24 * 60;

QuickDayControlInsights buildQuickDayControlInsights({
  required DateTime selectedDate,
  required UserWorkRules workRules,
  required List<CalendarDay> days,
  required List<DayMetrics> weekMetrics,
  required int liveExpectedMinutes,
  required int liveWorkedMinutes,
  required int liveLeaveMinutes,
  required bool hasLiveResultContext,
}) {
  final dailyCreditLimit = resolveConfiguredDailyCreditLimit(workRules);
  final dailyDebitLimit = resolveConfiguredDailyDebitLimit(workRules);
  final liveRawBalanceMinutes =
      (liveWorkedMinutes + liveLeaveMinutes) - liveExpectedMinutes;

  final controlledBalanceMinutes = resolveControlledDayBalanceMinutes(
    rawBalanceMinutes: liveRawBalanceMinutes,
    dailyCreditLimitMinutes: dailyCreditLimit,
    dailyDebitLimitMinutes: dailyDebitLimit,
  );
  final todayOvertimeMinutes = resolveDailyOvertimeMinutes(
    rawBalanceMinutes: liveRawBalanceMinutes,
    dailyCreditLimitMinutes: dailyCreditLimit,
  );

  final selectedDay = DateUtils.dateOnly(selectedDate);
  var weeklyOvertimeMinutes = 0;
  for (final metric in weekMetrics) {
    final usesLiveResult =
        isSameDay(metric.date, selectedDay) && hasLiveResultContext;
    if (!usesLiveResult && !metric.countsInBalance) {
      continue;
    }

    final rawBalanceMinutes = usesLiveResult
        ? liveRawBalanceMinutes
        : metric.rawBalanceMinutes;
    weeklyOvertimeMinutes += resolveDailyOvertimeMinutes(
      rawBalanceMinutes: rawBalanceMinutes,
      dailyCreditLimitMinutes: dailyCreditLimit,
    );
  }

  var monthlyOvertimeMinutes = 0;
  var monthlyRawBalanceMinutes = 0;
  for (final day in days) {
    final date = day.date;
    if (date == null || day.relation == CalendarDayRelation.future) {
      continue;
    }
    final usesLiveResult = isSameDay(date, selectedDay) && hasLiveResultContext;
    if (!usesLiveResult && !day.countsInBalance) {
      continue;
    }

    final rawBalanceMinutes = usesLiveResult
        ? liveRawBalanceMinutes
        : _registeredBalanceMinutes(day);
    monthlyRawBalanceMinutes += rawBalanceMinutes;
    monthlyOvertimeMinutes += resolveDailyOvertimeMinutes(
      rawBalanceMinutes: rawBalanceMinutes,
      dailyCreditLimitMinutes: dailyCreditLimit,
    );
  }

  final exceedsWithoutOvertime =
      todayOvertimeMinutes > 0 && !workRules.overtimeEnabled;
  final dailyOverflow =
      workRules.overtimeEnabled &&
          workRules.overtimeCapEnabled &&
          workRules.overtimeDailyCapMinutes > 0
      ? math.max(0, todayOvertimeMinutes - workRules.overtimeDailyCapMinutes)
      : 0;
  final weeklyOverflow =
      workRules.overtimeEnabled &&
          workRules.overtimeCapEnabled &&
          workRules.overtimeWeeklyCapMinutes > 0
      ? math.max(0, weeklyOvertimeMinutes - workRules.overtimeWeeklyCapMinutes)
      : 0;
  final monthlyOverflow =
      workRules.overtimeEnabled &&
          workRules.overtimeCapEnabled &&
          workRules.overtimeMonthlyCapMinutes > 0
      ? math.max(
          0,
          monthlyOvertimeMinutes - workRules.overtimeMonthlyCapMinutes,
        )
      : 0;
  final exceededOvertimeMinutes = exceedsWithoutOvertime
      ? todayOvertimeMinutes
      : [dailyOverflow, weeklyOverflow, monthlyOverflow].reduce(math.max);

  final hasMissingCreditLimit = workRules.maximumDailyCreditMinutes <= 0;
  final showConfigurationHint =
      hasLiveResultContext &&
      liveRawBalanceMinutes > 0 &&
      hasMissingCreditLimit;

  final configurationHint = hasMissingCreditLimit
      ? 'Imposta il massimo credito giornaliero in Orari e permessi, '
      : null;

  final exceededDailyCreditLimitMinutes =
      dailyCreditLimit != null && liveRawBalanceMinutes > dailyCreditLimit
      ? liveRawBalanceMinutes - dailyCreditLimit
      : 0;
  final exceededDailyDebitLimitMinutes =
      dailyDebitLimit != null && liveRawBalanceMinutes < -dailyDebitLimit
      ? (-liveRawBalanceMinutes) - dailyDebitLimit
      : 0;

  final monthlyCreditLimit = resolveConfiguredMonthlyCreditLimit(workRules);
  final monthlyDebitLimit = resolveConfiguredMonthlyDebitLimit(workRules);
  final exceededMonthlyCreditLimitMinutes =
      monthlyCreditLimit != null &&
          monthlyRawBalanceMinutes > monthlyCreditLimit
      ? monthlyRawBalanceMinutes - monthlyCreditLimit
      : 0;
  final exceededMonthlyDebitLimitMinutes =
      monthlyDebitLimit != null && monthlyRawBalanceMinutes < -monthlyDebitLimit
      ? (-monthlyRawBalanceMinutes) - monthlyDebitLimit
      : 0;

  final limitWarningText = switch ((
    exceededMonthlyCreditLimitMinutes,
    exceededMonthlyDebitLimitMinutes,
    exceededDailyCreditLimitMinutes,
    exceededDailyDebitLimitMinutes,
  )) {
    (> 0, _, _, _) =>
      'Superato limite credito mensile di ${formatHoursInput(exceededMonthlyCreditLimitMinutes)}',
    (_, > 0, _, _) =>
      'Superato limite debito mensile di ${formatHoursInput(exceededMonthlyDebitLimitMinutes)}',
    (_, _, > 0, _) =>
      'Superato limite credito giornaliero di ${formatHoursInput(exceededDailyCreditLimitMinutes)}',
    (_, _, _, > 0) =>
      'Superato limite debito giornaliero di ${formatHoursInput(exceededDailyDebitLimitMinutes)}',
    _ => null,
  };

  return QuickDayControlInsights(
    controlledBalanceMinutes: controlledBalanceMinutes,
    todayOvertimeMinutes: todayOvertimeMinutes,
    exceededOvertimeMinutes: exceededOvertimeMinutes,
    showConfigurationHint: showConfigurationHint,
    limitWarningText: limitWarningText,
    configurationHint: configurationHint,
  );
}

int resolveControlledDayBalanceMinutes({
  required int rawBalanceMinutes,
  required int? dailyCreditLimitMinutes,
  required int? dailyDebitLimitMinutes,
}) {
  if (rawBalanceMinutes > 0) {
    if (dailyCreditLimitMinutes == null) {
      return rawBalanceMinutes;
    }
    return math.min(rawBalanceMinutes, dailyCreditLimitMinutes);
  }
  if (rawBalanceMinutes < 0) {
    if (dailyDebitLimitMinutes == null) {
      return rawBalanceMinutes;
    }
    return -math.min(-rawBalanceMinutes, dailyDebitLimitMinutes);
  }
  return 0;
}

int resolveDailyOvertimeMinutes({
  required int rawBalanceMinutes,
  required int? dailyCreditLimitMinutes,
}) {
  if (rawBalanceMinutes <= 0 || dailyCreditLimitMinutes == null) {
    return 0;
  }
  return math.max(0, rawBalanceMinutes - dailyCreditLimitMinutes);
}

int? resolveConfiguredDailyCreditLimit(UserWorkRules workRules) {
  final creditLimit = workRules.maximumDailyCreditMinutes;
  if (creditLimit <= 0 || creditLimit >= unboundedDailyLimitMinutes) {
    return null;
  }
  return creditLimit;
}

int? resolveConfiguredDailyDebitLimit(UserWorkRules workRules) {
  final debitLimit = workRules.maximumDailyDebitMinutes;
  if (debitLimit <= 0 || debitLimit >= unboundedDailyLimitMinutes) {
    return null;
  }
  return debitLimit;
}

int? resolveConfiguredMonthlyCreditLimit(UserWorkRules workRules) {
  final creditLimit = workRules.maximumMonthlyCreditMinutes;
  if (creditLimit <= 0 || creditLimit >= unboundedMonthlyLimitMinutes) {
    return null;
  }
  return creditLimit;
}

int? resolveConfiguredMonthlyDebitLimit(UserWorkRules workRules) {
  final debitLimit = workRules.maximumMonthlyDebitMinutes;
  if (debitLimit <= 0 || debitLimit >= unboundedMonthlyLimitMinutes) {
    return null;
  }
  return debitLimit;
}
