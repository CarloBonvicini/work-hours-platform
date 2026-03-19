import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';

void main() {
  test('toJson omits empty start and end times', () {
    const schedule = DaySchedule(targetMinutes: 480, breakMinutes: 30);

    expect(schedule.toJson(), {
      'targetMinutes': 480,
      'breakMinutes': 30,
    });
  });

  test('toJson keeps start and end times when present', () {
    const schedule = DaySchedule(
      targetMinutes: 480,
      startTime: '08:30',
      endTime: '17:00',
      breakMinutes: 30,
    );

    expect(schedule.toJson(), {
      'targetMinutes': 480,
      'breakMinutes': 30,
      'startTime': '08:30',
      'endTime': '17:00',
    });
  });
}
