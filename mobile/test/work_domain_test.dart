import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/working_day.dart';

void main() {
  test('derives default work rules from the stored weekday schedule', () {
    final profile = UserProfile.fromJson({
      'id': 'profile-1',
      'fullName': 'Carlo',
      'useUniformDailyTarget': true,
      'dailyTargetMinutes': 480,
      'weekdayTargetMinutes': {
        'monday': 480,
        'tuesday': 480,
        'wednesday': 480,
        'thursday': 480,
        'friday': 480,
        'saturday': 0,
        'sunday': 0,
      },
      'weekdaySchedule': {
        'monday': {
          'targetMinutes': 480,
          'startTime': '08:30',
          'endTime': '17:00',
          'breakMinutes': 30,
        },
        'tuesday': {
          'targetMinutes': 480,
          'startTime': '08:30',
          'endTime': '17:00',
          'breakMinutes': 45,
        },
      },
    });

    expect(profile.workRules.expectedDailyMinutes, 480);
    expect(profile.workRules.minimumBreakMinutes, 30);
    expect(profile.workRules.maximumDailyCreditMinutes, 24 * 60);
    expect(profile.workRules.maximumMonthlyCreditMinutes, 31 * 24 * 60);
  });

  test('computes monthly balance and remaining credit or debit in minutes', () {
    const rules = UserWorkRules(
      expectedDailyMinutes: 480,
      minimumBreakMinutes: 30,
      maximumDailyCreditMinutes: 120,
      maximumDailyDebitMinutes: 90,
      maximumMonthlyCreditMinutes: 600,
      maximumMonthlyDebitMinutes: 480,
    );

    final summary = MonthlySummary.fromTotals(
      month: '2026-03',
      expectedMinutes: 9600,
      workedMinutes: 9900,
      leaveMinutes: 60,
      rules: rules,
    );

    expect(summary.balanceMinutes, 360);
    expect(summary.progressiveBalanceMinutes, 360);
    expect(summary.remainingCreditMinutes, 240);
    expect(summary.remainingDebitMinutes, 480);
  });

  test('builds a working day from minutes and applies daily rules', () {
    const rules = UserWorkRules(
      expectedDailyMinutes: 480,
      minimumBreakMinutes: 30,
      maximumDailyCreditMinutes: 30,
      maximumDailyDebitMinutes: 60,
      maximumMonthlyCreditMinutes: 600,
      maximumMonthlyDebitMinutes: 480,
    );

    final workday = WorkingDay.fromTimeRange(
      date: '2026-03-25',
      dayType: WorkingDayType.working,
      startMinutes: 8 * 60,
      endMinutes: 18 * 60,
      breakMinutes: 30,
      expectedMinutes: 8 * 60,
    );

    expect(workday.workedMinutes, 570);
    expect(workday.balanceMinutes, 90);

    final clampedWorkday = workday.applyingRules(rules);
    expect(clampedWorkday.balanceMinutes, 30);
  });

  test('derives default work rules from weekday schedule helper', () {
    const weekdaySchedule = WeekdaySchedule(
      monday: DaySchedule(targetMinutes: 480, breakMinutes: 30),
      tuesday: DaySchedule(targetMinutes: 480, breakMinutes: 45),
      wednesday: DaySchedule(targetMinutes: 480, breakMinutes: 30),
      thursday: DaySchedule(targetMinutes: 480, breakMinutes: 30),
      friday: DaySchedule(targetMinutes: 480, breakMinutes: 30),
      saturday: DaySchedule(targetMinutes: 0, breakMinutes: 0),
      sunday: DaySchedule(targetMinutes: 0, breakMinutes: 0),
    );

    final rules = UserProfile.defaultWorkRules(
      dailyTargetMinutes: 480,
      weekdaySchedule: weekdaySchedule,
    );

    expect(rules.expectedDailyMinutes, 480);
    expect(rules.minimumBreakMinutes, 30);
  });
}
