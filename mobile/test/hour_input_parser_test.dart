import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';

void main() {
  group('parseHoursInput', () {
    test('accepts common hour formats and standardizes them', () {
      expect(parseHoursInput('7'), 420);
      expect(parseHoursInput('7.5'), 450);
      expect(parseHoursInput('7,5'), 450);
      expect(parseHoursInput('7:30'), 450);
      expect(parseHoursInput('7.30'), 450);
      expect(parseHoursInput('7,30'), 450);
      expect(parseHoursInput('730'), 450);
      expect(parseHoursInput('0730'), 450);
      expect(parseHoursInput('7h30'), 450);
      expect(parseHoursInput('7 h 30'), 450);
      expect(parseHoursInput('7 ore 30'), 450);
      expect(parseHoursInput('7h'), 420);
      expect(parseHoursInput('7:5'), 425);
      expect(parseHoursInput('7.75'), 465);
    });

    test('rejects invalid values', () {
      expect(parseHoursInput(null), isNull);
      expect(parseHoursInput(''), isNull);
      expect(parseHoursInput('abc'), isNull);
      expect(parseHoursInput('-1'), isNull);
      expect(parseHoursInput('7:99'), isNull);
      expect(parseHoursInput('99999'), isNull);
    });
  });

  test('formatHoursInput returns canonical H:MM text', () {
    expect(formatHoursInput(420), '7:00');
    expect(formatHoursInput(450), '7:30');
    expect(formatHoursInput(425), '7:05');
  });
}
