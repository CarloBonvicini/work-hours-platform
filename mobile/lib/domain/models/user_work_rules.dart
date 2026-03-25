import 'dart:math' as math;

enum WorkPermissionMovement { entryLate, exitEarly, entryEarly, exitLate }

enum WorkAllowancePeriod { daily, weekly, monthly, yearly }

class WorkPermissionRule {
  const WorkPermissionRule({
    required this.id,
    required this.name,
    required this.enabled,
    required this.period,
    required this.allowanceMinutes,
    required this.usedMinutes,
    required this.movements,
  });

  final String id;
  final String name;
  final bool enabled;
  final WorkAllowancePeriod period;
  final int allowanceMinutes;
  final int usedMinutes;
  final List<WorkPermissionMovement> movements;

  factory WorkPermissionRule.fromJson(Map<String, dynamic> json) {
    final rawMovements = json['movements'];
    return WorkPermissionRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      period: WorkAllowancePeriodX.fromApiValue(
        json['period'] as String? ?? 'monthly',
      ),
      allowanceMinutes: (json['allowanceMinutes'] as num?)?.toInt() ?? 0,
      usedMinutes: (json['usedMinutes'] as num?)?.toInt() ?? 0,
      movements: rawMovements is List
          ? rawMovements
                .whereType<String>()
                .map(WorkPermissionMovementX.fromApiValue)
                .toSet()
                .toList(growable: false)
          : const [
              WorkPermissionMovement.entryLate,
              WorkPermissionMovement.exitEarly,
            ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'period': period.apiValue,
      'allowanceMinutes': allowanceMinutes,
      'usedMinutes': usedMinutes,
      'movements': movements
          .map((movement) => movement.apiValue)
          .toList(growable: false),
    };
  }

  WorkPermissionRule copyWith({
    String? id,
    String? name,
    bool? enabled,
    WorkAllowancePeriod? period,
    int? allowanceMinutes,
    int? usedMinutes,
    List<WorkPermissionMovement>? movements,
  }) {
    return WorkPermissionRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      period: period ?? this.period,
      allowanceMinutes: allowanceMinutes ?? this.allowanceMinutes,
      usedMinutes: usedMinutes ?? this.usedMinutes,
      movements: movements ?? this.movements,
    );
  }
}

class UserWorkRules {
  const UserWorkRules({
    required this.expectedDailyMinutes,
    required this.minimumBreakMinutes,
    required this.maximumDailyCreditMinutes,
    required this.maximumDailyDebitMinutes,
    required this.maximumMonthlyCreditMinutes,
    required this.maximumMonthlyDebitMinutes,
    this.overtimeEnabled = false,
    this.overtimeCapEnabled = false,
    this.overtimeDailyCapMinutes = 0,
    this.overtimeWeeklyCapMinutes = 0,
    this.overtimeMonthlyCapMinutes = 0,
    this.fixedScheduleEnabled = false,
    this.flexibleStartEnabled = false,
    this.flexibleStartWindowMinutes = 0,
    this.walletEnabled = false,
    this.walletDailyExitEarlyMinutes = 0,
    this.walletWeeklyExitEarlyMinutes = 0,
    this.implicitCreditEnabled = false,
    this.implicitCreditDailyCapMinutes = 0,
    this.additionalPermissions = const [],
    this.leaveBanks = const [],
  });

  static const int _unboundedDailyLimitMinutes = 24 * 60;
  static const int _unboundedMonthlyLimitMinutes = 31 * 24 * 60;

  final int expectedDailyMinutes;
  final int minimumBreakMinutes;
  final int maximumDailyCreditMinutes;
  final int maximumDailyDebitMinutes;
  final int maximumMonthlyCreditMinutes;
  final int maximumMonthlyDebitMinutes;
  final bool overtimeEnabled;
  final bool overtimeCapEnabled;
  final int overtimeDailyCapMinutes;
  final int overtimeWeeklyCapMinutes;
  final int overtimeMonthlyCapMinutes;
  final bool fixedScheduleEnabled;
  final bool flexibleStartEnabled;
  final int flexibleStartWindowMinutes;
  final bool walletEnabled;
  final int walletDailyExitEarlyMinutes;
  final int walletWeeklyExitEarlyMinutes;
  final bool implicitCreditEnabled;
  final int implicitCreditDailyCapMinutes;
  final List<WorkPermissionRule> additionalPermissions;
  final List<WorkPermissionRule> leaveBanks;

  factory UserWorkRules.unbounded({
    required int expectedDailyMinutes,
    int minimumBreakMinutes = 0,
  }) {
    return UserWorkRules(
      expectedDailyMinutes: expectedDailyMinutes,
      minimumBreakMinutes: minimumBreakMinutes,
      maximumDailyCreditMinutes: _unboundedDailyLimitMinutes,
      maximumDailyDebitMinutes: _unboundedDailyLimitMinutes,
      maximumMonthlyCreditMinutes: _unboundedMonthlyLimitMinutes,
      maximumMonthlyDebitMinutes: _unboundedMonthlyLimitMinutes,
    );
  }

  factory UserWorkRules.fromJson(
    Map<String, dynamic> json, {
    required int fallbackExpectedDailyMinutes,
    int fallbackMinimumBreakMinutes = 0,
  }) {
    final rawAdditionalPermissions = json['additionalPermissions'];
    final rawLeaveBanks = json['leaveBanks'];
    return UserWorkRules(
      expectedDailyMinutes:
          json['expectedDailyMinutes'] as int? ?? fallbackExpectedDailyMinutes,
      minimumBreakMinutes:
          json['minimumBreakMinutes'] as int? ?? fallbackMinimumBreakMinutes,
      maximumDailyCreditMinutes:
          json['maximumDailyCreditMinutes'] as int? ??
          _unboundedDailyLimitMinutes,
      maximumDailyDebitMinutes:
          json['maximumDailyDebitMinutes'] as int? ??
          _unboundedDailyLimitMinutes,
      maximumMonthlyCreditMinutes:
          json['maximumMonthlyCreditMinutes'] as int? ??
          _unboundedMonthlyLimitMinutes,
      maximumMonthlyDebitMinutes:
          json['maximumMonthlyDebitMinutes'] as int? ??
          _unboundedMonthlyLimitMinutes,
      overtimeEnabled: json['overtimeEnabled'] as bool? ?? false,
      overtimeCapEnabled: json['overtimeCapEnabled'] as bool? ?? false,
      overtimeDailyCapMinutes: (json['overtimeDailyCapMinutes'] as num?)
              ?.toInt() ??
          0,
      overtimeWeeklyCapMinutes: (json['overtimeWeeklyCapMinutes'] as num?)
              ?.toInt() ??
          0,
      overtimeMonthlyCapMinutes: (json['overtimeMonthlyCapMinutes'] as num?)
              ?.toInt() ??
          0,
      fixedScheduleEnabled: json['fixedScheduleEnabled'] as bool? ?? false,
      flexibleStartEnabled: json['flexibleStartEnabled'] as bool? ?? false,
      flexibleStartWindowMinutes:
          (json['flexibleStartWindowMinutes'] as num?)?.toInt() ?? 0,
      walletEnabled: json['walletEnabled'] as bool? ?? false,
      walletDailyExitEarlyMinutes:
          (json['walletDailyExitEarlyMinutes'] as num?)?.toInt() ?? 0,
      walletWeeklyExitEarlyMinutes:
          (json['walletWeeklyExitEarlyMinutes'] as num?)?.toInt() ?? 0,
      implicitCreditEnabled: json['implicitCreditEnabled'] as bool? ?? false,
      implicitCreditDailyCapMinutes:
          (json['implicitCreditDailyCapMinutes'] as num?)?.toInt() ?? 0,
      additionalPermissions: rawAdditionalPermissions is List
          ? rawAdditionalPermissions
                .whereType<Map<String, dynamic>>()
                .map(WorkPermissionRule.fromJson)
                .toList(growable: false)
          : const [],
      leaveBanks: rawLeaveBanks is List
          ? rawLeaveBanks
                .whereType<Map<String, dynamic>>()
                .map(WorkPermissionRule.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expectedDailyMinutes': expectedDailyMinutes,
      'minimumBreakMinutes': minimumBreakMinutes,
      'maximumDailyCreditMinutes': maximumDailyCreditMinutes,
      'maximumDailyDebitMinutes': maximumDailyDebitMinutes,
      'maximumMonthlyCreditMinutes': maximumMonthlyCreditMinutes,
      'maximumMonthlyDebitMinutes': maximumMonthlyDebitMinutes,
      'overtimeEnabled': overtimeEnabled,
      'overtimeCapEnabled': overtimeCapEnabled,
      'overtimeDailyCapMinutes': overtimeDailyCapMinutes,
      'overtimeWeeklyCapMinutes': overtimeWeeklyCapMinutes,
      'overtimeMonthlyCapMinutes': overtimeMonthlyCapMinutes,
      'fixedScheduleEnabled': fixedScheduleEnabled,
      'flexibleStartEnabled': flexibleStartEnabled,
      'flexibleStartWindowMinutes': flexibleStartWindowMinutes,
      'walletEnabled': walletEnabled,
      'walletDailyExitEarlyMinutes': walletDailyExitEarlyMinutes,
      'walletWeeklyExitEarlyMinutes': walletWeeklyExitEarlyMinutes,
      'implicitCreditEnabled': implicitCreditEnabled,
      'implicitCreditDailyCapMinutes': implicitCreditDailyCapMinutes,
      'additionalPermissions': additionalPermissions
          .map((rule) => rule.toJson())
          .toList(growable: false),
      'leaveBanks': leaveBanks
          .map((rule) => rule.toJson())
          .toList(growable: false),
    };
  }

  UserWorkRules copyWith({
    int? expectedDailyMinutes,
    int? minimumBreakMinutes,
    int? maximumDailyCreditMinutes,
    int? maximumDailyDebitMinutes,
    int? maximumMonthlyCreditMinutes,
    int? maximumMonthlyDebitMinutes,
    bool? overtimeEnabled,
    bool? overtimeCapEnabled,
    int? overtimeDailyCapMinutes,
    int? overtimeWeeklyCapMinutes,
    int? overtimeMonthlyCapMinutes,
    bool? fixedScheduleEnabled,
    bool? flexibleStartEnabled,
    int? flexibleStartWindowMinutes,
    bool? walletEnabled,
    int? walletDailyExitEarlyMinutes,
    int? walletWeeklyExitEarlyMinutes,
    bool? implicitCreditEnabled,
    int? implicitCreditDailyCapMinutes,
    List<WorkPermissionRule>? additionalPermissions,
    List<WorkPermissionRule>? leaveBanks,
  }) {
    return UserWorkRules(
      expectedDailyMinutes: expectedDailyMinutes ?? this.expectedDailyMinutes,
      minimumBreakMinutes: minimumBreakMinutes ?? this.minimumBreakMinutes,
      maximumDailyCreditMinutes:
          maximumDailyCreditMinutes ?? this.maximumDailyCreditMinutes,
      maximumDailyDebitMinutes:
          maximumDailyDebitMinutes ?? this.maximumDailyDebitMinutes,
      maximumMonthlyCreditMinutes:
          maximumMonthlyCreditMinutes ?? this.maximumMonthlyCreditMinutes,
      maximumMonthlyDebitMinutes:
          maximumMonthlyDebitMinutes ?? this.maximumMonthlyDebitMinutes,
      overtimeEnabled: overtimeEnabled ?? this.overtimeEnabled,
      overtimeCapEnabled: overtimeCapEnabled ?? this.overtimeCapEnabled,
      overtimeDailyCapMinutes:
          overtimeDailyCapMinutes ?? this.overtimeDailyCapMinutes,
      overtimeWeeklyCapMinutes:
          overtimeWeeklyCapMinutes ?? this.overtimeWeeklyCapMinutes,
      overtimeMonthlyCapMinutes:
          overtimeMonthlyCapMinutes ?? this.overtimeMonthlyCapMinutes,
      fixedScheduleEnabled: fixedScheduleEnabled ?? this.fixedScheduleEnabled,
      flexibleStartEnabled: flexibleStartEnabled ?? this.flexibleStartEnabled,
      flexibleStartWindowMinutes:
          flexibleStartWindowMinutes ?? this.flexibleStartWindowMinutes,
      walletEnabled: walletEnabled ?? this.walletEnabled,
      walletDailyExitEarlyMinutes:
          walletDailyExitEarlyMinutes ?? this.walletDailyExitEarlyMinutes,
      walletWeeklyExitEarlyMinutes:
          walletWeeklyExitEarlyMinutes ?? this.walletWeeklyExitEarlyMinutes,
      implicitCreditEnabled: implicitCreditEnabled ?? this.implicitCreditEnabled,
      implicitCreditDailyCapMinutes:
          implicitCreditDailyCapMinutes ?? this.implicitCreditDailyCapMinutes,
      additionalPermissions:
          additionalPermissions ?? this.additionalPermissions,
      leaveBanks: leaveBanks ?? this.leaveBanks,
    );
  }

  int clampDailyBalance(int balanceMinutes) {
    if (balanceMinutes >= 0) {
      return _clampMinutes(balanceMinutes, 0, _effectiveDailyCreditLimit());
    }
    return -_clampMinutes(-balanceMinutes, 0, _effectiveDailyDebitLimit());
  }

  int clampMonthlyBalance(int balanceMinutes) {
    if (balanceMinutes >= 0) {
      return _clampMinutes(balanceMinutes, 0, _effectiveMonthlyCreditLimit());
    }
    return -_clampMinutes(-balanceMinutes, 0, _effectiveMonthlyDebitLimit());
  }

  int remainingMonthlyCreditMinutes(int balanceMinutes) {
    final limit = _effectiveMonthlyCreditLimit();
    return _clampMinutes(limit - balanceMinutes, 0, limit);
  }

  int remainingMonthlyDebitMinutes(int balanceMinutes) {
    final limit = _effectiveMonthlyDebitLimit();
    return _clampMinutes(limit + balanceMinutes, 0, limit);
  }

  int _effectiveDailyCreditLimit() {
    var limit = maximumDailyCreditMinutes;
    if (overtimeEnabled) {
      if (overtimeCapEnabled && overtimeDailyCapMinutes > 0) {
        limit = math.min(limit, overtimeDailyCapMinutes);
      }
      return limit;
    }

    if (!implicitCreditEnabled) {
      return 0;
    }

    if (implicitCreditDailyCapMinutes <= 0) {
      return 0;
    }
    return math.min(limit, implicitCreditDailyCapMinutes);
  }

  int _effectiveDailyDebitLimit() {
    if (!walletEnabled) {
      return maximumDailyDebitMinutes;
    }
    if (walletDailyExitEarlyMinutes <= 0) {
      return maximumDailyDebitMinutes;
    }
    return math.min(maximumDailyDebitMinutes, walletDailyExitEarlyMinutes);
  }

  int _effectiveMonthlyCreditLimit() {
    if (!overtimeEnabled || !overtimeCapEnabled || overtimeMonthlyCapMinutes <= 0) {
      return maximumMonthlyCreditMinutes;
    }
    return math.min(maximumMonthlyCreditMinutes, overtimeMonthlyCapMinutes);
  }

  int _effectiveMonthlyDebitLimit() {
    return maximumMonthlyDebitMinutes;
  }

  int _clampMinutes(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}

extension WorkPermissionMovementX on WorkPermissionMovement {
  static WorkPermissionMovement fromApiValue(String value) {
    switch (value) {
      case 'entry_late':
        return WorkPermissionMovement.entryLate;
      case 'exit_early':
        return WorkPermissionMovement.exitEarly;
      case 'entry_early':
        return WorkPermissionMovement.entryEarly;
      case 'exit_late':
      default:
        return WorkPermissionMovement.exitLate;
    }
  }

  String get apiValue {
    switch (this) {
      case WorkPermissionMovement.entryLate:
        return 'entry_late';
      case WorkPermissionMovement.exitEarly:
        return 'exit_early';
      case WorkPermissionMovement.entryEarly:
        return 'entry_early';
      case WorkPermissionMovement.exitLate:
        return 'exit_late';
    }
  }

  String get label {
    switch (this) {
      case WorkPermissionMovement.entryLate:
        return 'Ingresso posticipato';
      case WorkPermissionMovement.exitEarly:
        return 'Uscita anticipata';
      case WorkPermissionMovement.entryEarly:
        return 'Ingresso anticipato';
      case WorkPermissionMovement.exitLate:
        return 'Uscita posticipata';
    }
  }
}

extension WorkAllowancePeriodX on WorkAllowancePeriod {
  static WorkAllowancePeriod fromApiValue(String value) {
    switch (value) {
      case 'daily':
        return WorkAllowancePeriod.daily;
      case 'weekly':
        return WorkAllowancePeriod.weekly;
      case 'yearly':
        return WorkAllowancePeriod.yearly;
      case 'monthly':
      default:
        return WorkAllowancePeriod.monthly;
    }
  }

  String get apiValue {
    switch (this) {
      case WorkAllowancePeriod.daily:
        return 'daily';
      case WorkAllowancePeriod.weekly:
        return 'weekly';
      case WorkAllowancePeriod.monthly:
        return 'monthly';
      case WorkAllowancePeriod.yearly:
        return 'yearly';
    }
  }

  String get label {
    switch (this) {
      case WorkAllowancePeriod.daily:
        return 'Giornaliero';
      case WorkAllowancePeriod.weekly:
        return 'Settimanale';
      case WorkAllowancePeriod.monthly:
        return 'Mensile';
      case WorkAllowancePeriod.yearly:
        return 'Annuale';
    }
  }
}
