import 'package:work_hours_mobile/domain/models/user_work_rules.dart';

class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.rawBalanceMinutes,
    required this.balanceMinutes,
    this.remainingCreditMinutes = 0,
    this.remainingDebitMinutes = 0,
  });

  final String month;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int rawBalanceMinutes;
  final int balanceMinutes;
  final int remainingCreditMinutes;
  final int remainingDebitMinutes;

  factory MonthlySummary.fromTotals({
    required String month,
    required int expectedMinutes,
    required int workedMinutes,
    int leaveMinutes = 0,
    required UserWorkRules rules,
  }) {
    final rawBalanceMinutes = workedMinutes + leaveMinutes - expectedMinutes;
    return MonthlySummary(
      month: month,
      expectedMinutes: expectedMinutes,
      workedMinutes: workedMinutes,
      leaveMinutes: leaveMinutes,
      rawBalanceMinutes: rawBalanceMinutes,
      balanceMinutes: rules.clampMonthlyBalance(rawBalanceMinutes),
      remainingCreditMinutes: rules.remainingMonthlyCreditMinutes(
        rawBalanceMinutes,
      ),
      remainingDebitMinutes: rules.remainingMonthlyDebitMinutes(
        rawBalanceMinutes,
      ),
    );
  }

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    final expectedMinutes =
        json['expectedMinutes'] as int? ??
        json['totalExpectedMinutes'] as int? ??
        0;
    final workedMinutes =
        json['workedMinutes'] as int? ??
        json['totalWorkedMinutes'] as int? ??
        0;
    final leaveMinutes = json['leaveMinutes'] as int? ?? 0;
    final balanceMinutes =
        json['balanceMinutes'] as int? ??
        json['progressiveBalanceMinutes'] as int? ??
        (workedMinutes + leaveMinutes - expectedMinutes);
    final rawBalanceMinutes =
        json['rawBalanceMinutes'] as int? ?? balanceMinutes;

    return MonthlySummary(
      month: json['month'] as String,
      expectedMinutes: expectedMinutes,
      workedMinutes: workedMinutes,
      leaveMinutes: leaveMinutes,
      rawBalanceMinutes: rawBalanceMinutes,
      balanceMinutes: balanceMinutes,
      remainingCreditMinutes:
          json['remainingCreditMinutes'] as int? ??
          json['residualCreditMinutes'] as int? ??
          0,
      remainingDebitMinutes:
          json['remainingDebitMinutes'] as int? ??
          json['residualDebitMinutes'] as int? ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'expectedMinutes': expectedMinutes,
      'workedMinutes': workedMinutes,
      'leaveMinutes': leaveMinutes,
      'rawBalanceMinutes': rawBalanceMinutes,
      'balanceMinutes': balanceMinutes,
      'totalExpectedMinutes': totalExpectedMinutes,
      'totalWorkedMinutes': totalWorkedMinutes,
      'progressiveBalanceMinutes': progressiveBalanceMinutes,
      'remainingCreditMinutes': remainingCreditMinutes,
      'remainingDebitMinutes': remainingDebitMinutes,
      'residualCreditMinutes': remainingCreditMinutes,
      'residualDebitMinutes': remainingDebitMinutes,
    };
  }

  int get totalWorkedMinutes => workedMinutes;

  int get totalExpectedMinutes => expectedMinutes;

  int get progressiveBalanceMinutes => balanceMinutes;

  int get residualCreditMinutes => remainingCreditMinutes;

  int get residualDebitMinutes => remainingDebitMinutes;

  MonthlySummary applyingRules(UserWorkRules rules) {
    return MonthlySummary(
      month: month,
      expectedMinutes: expectedMinutes,
      workedMinutes: workedMinutes,
      leaveMinutes: leaveMinutes,
      rawBalanceMinutes: rawBalanceMinutes,
      balanceMinutes: rules.clampMonthlyBalance(rawBalanceMinutes),
      remainingCreditMinutes: rules.remainingMonthlyCreditMinutes(
        rawBalanceMinutes,
      ),
      remainingDebitMinutes: rules.remainingMonthlyDebitMinutes(
        rawBalanceMinutes,
      ),
    );
  }
}
