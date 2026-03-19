class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.balanceMinutes,
  });

  final String month;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int balanceMinutes;

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      month: json['month'] as String,
      expectedMinutes: json['expectedMinutes'] as int,
      workedMinutes: json['workedMinutes'] as int,
      leaveMinutes: json['leaveMinutes'] as int,
      balanceMinutes: json['balanceMinutes'] as int,
    );
  }
}
