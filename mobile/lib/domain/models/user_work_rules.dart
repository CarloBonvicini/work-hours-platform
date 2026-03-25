class UserWorkRules {
  const UserWorkRules({
    required this.expectedDailyMinutes,
    required this.minimumBreakMinutes,
    required this.maximumDailyCreditMinutes,
    required this.maximumDailyDebitMinutes,
    required this.maximumMonthlyCreditMinutes,
    required this.maximumMonthlyDebitMinutes,
  });

  static const int _unboundedDailyLimitMinutes = 24 * 60;
  static const int _unboundedMonthlyLimitMinutes = 31 * 24 * 60;

  final int expectedDailyMinutes;
  final int minimumBreakMinutes;
  final int maximumDailyCreditMinutes;
  final int maximumDailyDebitMinutes;
  final int maximumMonthlyCreditMinutes;
  final int maximumMonthlyDebitMinutes;

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
    };
  }

  UserWorkRules copyWith({
    int? expectedDailyMinutes,
    int? minimumBreakMinutes,
    int? maximumDailyCreditMinutes,
    int? maximumDailyDebitMinutes,
    int? maximumMonthlyCreditMinutes,
    int? maximumMonthlyDebitMinutes,
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
    );
  }

  int clampDailyBalance(int balanceMinutes) {
    if (balanceMinutes >= 0) {
      return _clampMinutes(balanceMinutes, 0, maximumDailyCreditMinutes);
    }
    return -_clampMinutes(-balanceMinutes, 0, maximumDailyDebitMinutes);
  }

  int clampMonthlyBalance(int balanceMinutes) {
    if (balanceMinutes >= 0) {
      return _clampMinutes(balanceMinutes, 0, maximumMonthlyCreditMinutes);
    }
    return -_clampMinutes(-balanceMinutes, 0, maximumMonthlyDebitMinutes);
  }

  int remainingMonthlyCreditMinutes(int balanceMinutes) {
    return _clampMinutes(
      maximumMonthlyCreditMinutes - balanceMinutes,
      0,
      maximumMonthlyCreditMinutes,
    );
  }

  int remainingMonthlyDebitMinutes(int balanceMinutes) {
    return _clampMinutes(
      maximumMonthlyDebitMinutes + balanceMinutes,
      0,
      maximumMonthlyDebitMinutes,
    );
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
