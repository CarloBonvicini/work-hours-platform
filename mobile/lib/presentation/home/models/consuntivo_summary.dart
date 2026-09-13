// Modelli di vista del consuntivo: periodo, totali, mesi, permessi e giorni.

enum ConsuntivoRangeOption { oneMonth, threeMonths, twelveMonths }

extension ConsuntivoRangeOptionX on ConsuntivoRangeOption {
  int get monthCount {
    switch (this) {
      case ConsuntivoRangeOption.oneMonth:
        return 1;
      case ConsuntivoRangeOption.threeMonths:
        return 3;
      case ConsuntivoRangeOption.twelveMonths:
        return 12;
    }
  }

  String get label {
    switch (this) {
      case ConsuntivoRangeOption.oneMonth:
        return '1 mese';
      case ConsuntivoRangeOption.threeMonths:
        return '3 mesi';
      case ConsuntivoRangeOption.twelveMonths:
        return '12 mesi';
    }
  }
}

class ConsuntivoSectionData {
  const ConsuntivoSectionData({
    required this.anchorMonthLabel,
    required this.periodLabel,
    required this.totals,
    required this.months,
    required this.permissions,
    required this.days,
    required this.hiddenDaysCount,
  });

  final String anchorMonthLabel;
  final String periodLabel;
  final ConsuntivoTotals totals;
  final List<ConsuntivoMonthSummary> months;
  final List<ConsuntivoPermissionSummary> permissions;
  final List<ConsuntivoDaySummary> days;
  final int hiddenDaysCount;
}

class ConsuntivoTotals {
  const ConsuntivoTotals({
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.rawBalanceMinutes,
    required this.clampedBalanceMinutes,
    required this.overtimeMaturedMinutes,
    required this.debitMaturedMinutes,
  });

  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int rawBalanceMinutes;
  final int clampedBalanceMinutes;
  final int overtimeMaturedMinutes;
  final int debitMaturedMinutes;
}

class ConsuntivoMonthSummary {
  const ConsuntivoMonthSummary({
    required this.monthLabel,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.balanceMinutes,
  });

  final String monthLabel;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int balanceMinutes;
}

class ConsuntivoPermissionSummary {
  const ConsuntivoPermissionSummary({
    required this.name,
    required this.periodLabel,
    required this.enabled,
    required this.allowanceLabel,
    required this.usedLabel,
    required this.remainingLabel,
    required this.movementsLabel,
  });

  final String name;
  final String periodLabel;
  final bool enabled;
  final String allowanceLabel;
  final String usedLabel;
  final String remainingLabel;
  final String movementsLabel;
}

class ConsuntivoDaySummary {
  const ConsuntivoDaySummary({
    required this.dateLabel,
    required this.plannedLabel,
    required this.registeredLabel,
    required this.balanceMinutes,
    this.scheduleDetail,
    this.causalDetail,
  });

  final String dateLabel;
  final String plannedLabel;
  final String registeredLabel;
  final int balanceMinutes;
  final String? scheduleDetail;
  final String? causalDetail;
}
