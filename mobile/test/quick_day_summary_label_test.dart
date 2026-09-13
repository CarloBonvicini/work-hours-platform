import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/logic/quick_day_summary_label.dart';

String labelFor({
  bool isDayOff = false,
  bool hasResultContext = false,
  int workedMinutes = 0,
  String startTimeText = '09:00',
  String endTimeText = '18:00',
  String plannedStartTimeText = '',
  String plannedEndTimeText = '',
  String targetText = '8:00',
}) {
  return buildQuickDaySummaryLabel(
    isDayOff: isDayOff,
    hasResultContext: hasResultContext,
    workedMinutes: workedMinutes,
    startTimeText: startTimeText,
    endTimeText: endTimeText,
    plannedStartTimeText: plannedStartTimeText,
    plannedEndTimeText: plannedEndTimeText,
    targetText: targetText,
  );
}

void main() {
  group('buildQuickDaySummaryLabel', () {
    test('a giornata non iniziata mostra orario e ore previste', () {
      expect(labelFor(), '09:00-18:00 · 8:00 previste');
    });

    test('a giornata avviata mostra le ore lavorate', () {
      expect(
        labelFor(hasResultContext: true, workedMinutes: (5 * 60) + 30),
        'Lavorate 5:30',
      );
    });

    test('una giornata libera lo dice e basta', () {
      expect(
        labelFor(isDayOff: true, hasResultContext: true),
        'Giornata libera',
      );
    });

    test('senza orari resta solo il monte ore', () {
      expect(labelFor(startTimeText: '', endTimeText: ''), '8:00 previste');
    });

    test('senza orari ne ore non inventa nulla', () {
      expect(
        labelFor(startTimeText: '', endTimeText: '', targetText: ''),
        'Da impostare',
      );
    });

    test('con gli orari ma senza monte ore mostra la fascia', () {
      expect(labelFor(targetText: ''), '09:00-18:00');
    });
  });

  test('senza orari registrati ripiega su quelli previsti', () {
    expect(
      labelFor(
        startTimeText: '',
        endTimeText: '',
        plannedStartTimeText: '08:30',
        plannedEndTimeText: '17:00',
      ),
      '08:30-17:00 · 8:00 previste',
    );
  });
}
