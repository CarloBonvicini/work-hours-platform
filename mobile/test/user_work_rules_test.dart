import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';

void main() {
  group('UserWorkRules pauseAdjustmentMode', () {
    test('defaults to keepWorkedMinutes when missing in payload', () {
      final rules = UserWorkRules.fromJson({
        'expectedDailyMinutes': 480,
        'minimumBreakMinutes': 0,
        'maximumDailyCreditMinutes': 1440,
        'maximumDailyDebitMinutes': 1440,
        'maximumMonthlyCreditMinutes': 44640,
        'maximumMonthlyDebitMinutes': 44640,
      }, fallbackExpectedDailyMinutes: 480);

      expect(
        rules.pauseAdjustmentMode,
        WorkRulesPauseAdjustmentMode.keepWorkedMinutes,
      );
    });

    test('parses and serializes keepEndTime mode', () {
      final rules = UserWorkRules.fromJson({
        'expectedDailyMinutes': 480,
        'minimumBreakMinutes': 0,
        'maximumDailyCreditMinutes': 1440,
        'maximumDailyDebitMinutes': 1440,
        'maximumMonthlyCreditMinutes': 44640,
        'maximumMonthlyDebitMinutes': 44640,
        'pauseAdjustmentMode': 'keep_end_time',
      }, fallbackExpectedDailyMinutes: 480);

      expect(
        rules.pauseAdjustmentMode,
        WorkRulesPauseAdjustmentMode.keepEndTime,
      );
      expect(rules.toJson()['pauseAdjustmentMode'], 'keep_end_time');
    });
  });
}
