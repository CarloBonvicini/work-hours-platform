import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/logic/section_history.dart';
import 'package:work_hours_mobile/presentation/home/models/home_section.dart';

void main() {
  test('senza spostamenti non c e niente dietro', () {
    expect(SectionHistory().canGoBack, isFalse);
    expect(SectionHistory().back(), isNull);
  });

  test('torna alla sezione da cui eri partito', () {
    final history = SectionHistory();
    history.record(HomeSection.day, HomeSection.workSettings);

    expect(history.canGoBack, isTrue);
    expect(history.back(), HomeSection.day);
    expect(history.canGoBack, isFalse);
  });

  test('torna indietro un passo alla volta', () {
    final history = SectionHistory();
    history.record(HomeSection.day, HomeSection.calendar);
    history.record(HomeSection.calendar, HomeSection.workSettings);

    expect(history.back(), HomeSection.calendar);
    expect(history.back(), HomeSection.day);
    expect(history.back(), isNull);
  });

  test('restare sulla stessa sezione non aggiunge un passo', () {
    final history = SectionHistory();
    history.record(HomeSection.day, HomeSection.day);

    expect(history.canGoBack, isFalse);
  });

  test('la memoria non cresce all infinito', () {
    final history = SectionHistory(maxEntries: 3);
    for (final section in [
      HomeSection.day,
      HomeSection.calendar,
      HomeSection.consuntivo,
      HomeSection.ticket,
    ]) {
      history.record(section, HomeSection.profile);
    }

    // Il passo piu' vecchio esce, gli ultimi tre restano.
    expect(history.entries, [
      HomeSection.calendar,
      HomeSection.consuntivo,
      HomeSection.ticket,
    ]);
  });
}
