import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';

void main() {
  group('WorkPermissionRule allowanceType', () {
    test('defaults to hours when allowanceType is missing', () {
      final rule = WorkPermissionRule.fromJson({
        'id': 'perm-1',
        'name': 'P36',
        'enabled': true,
        'period': 'yearly',
        'allowanceMinutes': 180,
        'usedMinutes': 60,
        'movements': ['entry_late'],
      });

      expect(rule.allowanceType, WorkPermissionAllowanceType.hours);
      expect(rule.allowanceDays, 0);
      expect(rule.usedDays, 0);
    });

    test('parses and serializes both hours and days', () {
      final rule = WorkPermissionRule.fromJson({
        'id': 'perm-2',
        'name': 'Particolari motivi',
        'enabled': true,
        'period': 'yearly',
        'allowanceType': 'both',
        'allowanceMinutes': 180,
        'usedMinutes': 60,
        'allowanceDays': 2,
        'usedDays': 1,
        'movements': ['entry_late', 'exit_early'],
      });

      expect(rule.allowanceType, WorkPermissionAllowanceType.both);
      expect(rule.allowanceMinutes, 180);
      expect(rule.usedMinutes, 60);
      expect(rule.allowanceDays, 2);
      expect(rule.usedDays, 1);
      expect(rule.toJson()['allowanceType'], 'both');
      expect(rule.toJson()['allowanceDays'], 2);
      expect(rule.toJson()['usedDays'], 1);
    });
  });

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
